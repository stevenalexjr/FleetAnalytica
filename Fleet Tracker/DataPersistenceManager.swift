//
//  DataPersistenceManager.swift
//  Fleet Tracker
//
//  Created by Steven Alexander on 9/20/25.
//

import Foundation
import FirebaseFirestore
import CoreLocation

// MARK: - Data Persistence Strategy

enum PersistenceStrategy {
    case firebaseOnly
    case localOnly
    case hybrid // Local first, sync to Firebase
    case offlineFirst // Local with offline queue
}

// MARK: - Data Persistence Manager

class DataPersistenceManager {
    static let shared = DataPersistenceManager()
    
    private let configuration = ConfigurationManager.shared
    private let logger = Logger.shared
    private let errorHandler = ErrorHandler.shared
    private let dataValidator = DataValidator.shared
    
    private let db = Firestore.firestore()
    private var persistenceStrategy: PersistenceStrategy = .hybrid
    
    // Local storage
    private let userDefaults = UserDefaults.standard
    private let fileManager = FileManager.default
    
    // Offline queue for failed operations
    private var offlineQueue: [OfflineOperation] = []
    private let offlineQueueKey = "offline_operations_queue"
    
    // Batch processing
    private var pendingLocationRecords: [LocationRecord] = []
    private var pendingTrips: [Trip] = []
    private let batchSize = 20
    private let batchTimeout: TimeInterval = 30.0
    private var batchTimer: Timer?
    
    private init() {
        loadOfflineQueue()
        setupBatchTimer()
    }
    
    // MARK: - Configuration
    
    func setPersistenceStrategy(_ strategy: PersistenceStrategy) {
        persistenceStrategy = strategy
        logger.info("Persistence strategy set to: \(strategy)")
    }
    
    func getPersistenceStrategy() -> PersistenceStrategy {
        return persistenceStrategy
    }
    
    // MARK: - Location Records
    
    func saveLocationRecord(_ record: LocationRecord) async {
        // Validate data first
        let validationResult = dataValidator.validateLocationRecord(record)
        if !validationResult.isValid {
            for error in validationResult.errors {
                if error.severity == .error {
                    logger.error("Location record validation failed: \(error.message)")
                    return
                } else {
                    logger.warning("Location record validation warning: \(error.message)")
                }
            }
        }
        
        switch persistenceStrategy {
        case .firebaseOnly:
            await saveToFirebase(record)
        case .localOnly:
            await saveToLocal(record)
        case .hybrid:
            await saveToLocal(record)
            await saveToFirebase(record)
        case .offlineFirst:
            await saveToLocal(record)
            await queueForFirebase(record)
        }
    }
    
    func saveLocationRecords(_ records: [LocationRecord]) async {
        // Validate batch
        let validationResult = dataValidator.validateBatch(records)
        if !validationResult.isValid {
            for error in validationResult.errors {
                if error.severity == .error {
                    logger.error("Batch validation failed: \(error.message)")
                    return
                } else {
                    logger.warning("Batch validation warning: \(error.message)")
                }
            }
        }
        
        switch persistenceStrategy {
        case .firebaseOnly:
            await saveBatchToFirebase(records)
        case .localOnly:
            await saveBatchToLocal(records)
        case .hybrid:
            await saveBatchToLocal(records)
            await saveBatchToFirebase(records)
        case .offlineFirst:
            await saveBatchToLocal(records)
            await queueBatchForFirebase(records)
        }
    }
    
    func loadLocationRecords(deviceId: String) async -> [LocationRecord] {
        switch persistenceStrategy {
        case .firebaseOnly:
            return await loadFromFirebase(deviceId: deviceId)
        case .localOnly:
            return await loadFromLocal(deviceId: deviceId)
        case .hybrid, .offlineFirst:
            // Try Firebase first, fallback to local
            let firebaseRecords = await loadFromFirebase(deviceId: deviceId)
            if !firebaseRecords.isEmpty {
                return firebaseRecords
            }
            return await loadFromLocal(deviceId: deviceId)
        }
    }
    
    // MARK: - Trips
    
    func saveTrip(_ trip: Trip) async {
        // Validate trip
        let validationResult = dataValidator.validateTrip(trip)
        if !validationResult.isValid {
            for error in validationResult.errors {
                if error.severity == .error {
                    logger.error("Trip validation failed: \(error.message)")
                    return
                } else {
                    logger.warning("Trip validation warning: \(error.message)")
                }
            }
        }
        
        switch persistenceStrategy {
        case .firebaseOnly:
            await saveTripToFirebase(trip)
        case .localOnly:
            await saveTripToLocal(trip)
        case .hybrid:
            await saveTripToLocal(trip)
            await saveTripToFirebase(trip)
        case .offlineFirst:
            await saveTripToLocal(trip)
            await queueTripForFirebase(trip)
        }
    }
    
    func loadTrips(deviceId: String) async -> [Trip] {
        switch persistenceStrategy {
        case .firebaseOnly:
            return await loadTripsFromFirebase(deviceId: deviceId)
        case .localOnly:
            return await loadTripsFromLocal(deviceId: deviceId)
        case .hybrid, .offlineFirst:
            // Try Firebase first, fallback to local
            let firebaseTrips = await loadTripsFromFirebase(deviceId: deviceId)
            if !firebaseTrips.isEmpty {
                return firebaseTrips
            }
            return await loadTripsFromLocal(deviceId: deviceId)
        }
    }
    
    // MARK: - Firebase Operations
    
    private func saveToFirebase(_ record: LocationRecord) async {
        do {
            let data = try Firestore.Encoder().encode(record)
            try await db.collection("locations").addDocument(data: data)
            logger.firebase("Location record saved to Firebase")
        } catch {
            await errorHandler.handleAsync(error, context: "Firebase location save", userFacing: false)
        }
    }
    
    private func saveBatchToFirebase(_ records: [LocationRecord]) async {
        guard !records.isEmpty else { return }
        
        let batch = db.batch()
        
        for record in records {
            do {
                let data = try Firestore.Encoder().encode(record)
                let docRef = db.collection("locations").document()
                batch.setData(data, forDocument: docRef)
            } catch {
                await errorHandler.handleAsync(error, context: "Firebase batch encoding", userFacing: false)
            }
        }
        
        do {
            try await batch.commit()
            logger.firebase("Batch of \(records.count) location records saved to Firebase")
        } catch {
            await errorHandler.handleAsync(error, context: "Firebase batch commit", userFacing: false)
        }
    }
    
    private func loadFromFirebase(deviceId: String) async -> [LocationRecord] {
        do {
            let snapshot = try await db.collection("locations")
                .whereField("deviceId", isEqualTo: deviceId)
                .limit(to: 500)
                .getDocuments()
            
            let records = snapshot.documents.compactMap { document -> LocationRecord? in
                do {
                    return try Firestore.Decoder().decode(LocationRecord.self, from: document.data())
                } catch {
                    errorHandler.handle(error, context: "Firebase location decoding", userFacing: false)
                    return nil
                }
            }
            
            logger.firebase("Loaded \(records.count) location records from Firebase")
            return records.sorted { $0.timestamp > $1.timestamp }
        } catch {
            await errorHandler.handleAsync(error, context: "Firebase location load", userFacing: true)
            return []
        }
    }
    
    private func saveTripToFirebase(_ trip: Trip) async {
        do {
            let data = try Firestore.Encoder().encode(trip)
            try await db.collection("trips").addDocument(data: data)
            logger.firebase("Trip saved to Firebase")
        } catch {
            await errorHandler.handleAsync(error, context: "Firebase trip save", userFacing: false)
        }
    }
    
    private func loadTripsFromFirebase(deviceId: String) async -> [Trip] {
        do {
            let snapshot = try await db.collection("trips")
                .whereField("deviceId", isEqualTo: deviceId)
                .limit(to: 100)
                .getDocuments()
            
            let trips = snapshot.documents.compactMap { document -> Trip? in
                do {
                    return try Firestore.Decoder().decode(Trip.self, from: document.data())
                } catch {
                    errorHandler.handle(error, context: "Firebase trip decoding", userFacing: false)
                    return nil
                }
            }
            
            logger.firebase("Loaded \(trips.count) trips from Firebase")
            return trips.sorted { $0.startTime > $1.startTime }
        } catch {
            await errorHandler.handleAsync(error, context: "Firebase trip load", userFacing: true)
            return []
        }
    }
    
    // MARK: - Local Storage Operations
    
    private func saveToLocal(_ record: LocationRecord) async {
        // Save to local file
        let fileName = "location_records_\(record.deviceId ?? "unknown").json"
        await appendToLocalFile(record, fileName: fileName)
    }
    
    private func saveBatchToLocal(_ records: [LocationRecord]) async {
        guard !records.isEmpty else { return }
        
        // Group by device ID
        let groupedRecords = Dictionary(grouping: records) { $0.deviceId ?? "unknown" }
        
        for (deviceId, deviceRecords) in groupedRecords {
            let fileName = "location_records_\(deviceId).json"
            await appendToLocalFile(deviceRecords, fileName: fileName)
        }
    }
    
    private func loadFromLocal(deviceId: String) async -> [LocationRecord] {
        let fileName = "location_records_\(deviceId).json"
        return await loadFromLocalFile(fileName: fileName, type: LocationRecord.self)
    }
    
    private func saveTripToLocal(_ trip: Trip) async {
        let fileName = "trips_\(trip.deviceId).json"
        await appendToLocalFile(trip, fileName: fileName)
    }
    
    private func loadTripsFromLocal(deviceId: String) async -> [Trip] {
        let fileName = "trips_\(deviceId).json"
        return await loadFromLocalFile(fileName: fileName, type: Trip.self)
    }
    
    // MARK: - Local File Operations
    
    private func getDocumentsDirectory() -> URL {
        let paths = fileManager.urls(for: .documentDirectory, in: .userDomainMask)
        return paths[0]
    }
    
    private func getFilePath(fileName: String) -> URL {
        return getDocumentsDirectory().appendingPathComponent(fileName)
    }
    
    private func appendToLocalFile<T: Codable>(_ item: T, fileName: String) async {
        let filePath = getFilePath(fileName: fileName)
        
        do {
            var items: [T] = []
            
            // Load existing data
            if fileManager.fileExists(atPath: filePath.path) {
                let data = try Data(contentsOf: filePath)
                items = try JSONDecoder().decode([T].self, from: data)
            }
            
            // Append new item
            items.append(item)
            
            // Save back to file
            let data = try JSONEncoder().encode(items)
            try data.write(to: filePath)
            
            logger.debug("Saved item to local file: \(fileName)")
        } catch {
            errorHandler.handle(error, context: "Local file save", userFacing: false)
        }
    }
    
    private func appendToLocalFile<T: Codable>(_ items: [T], fileName: String) async {
        let filePath = getFilePath(fileName: fileName)
        
        do {
            var existingItems: [T] = []
            
            // Load existing data
            if fileManager.fileExists(atPath: filePath.path) {
                let data = try Data(contentsOf: filePath)
                existingItems = try JSONDecoder().decode([T].self, from: data)
            }
            
            // Append new items
            existingItems.append(contentsOf: items)
            
            // Save back to file
            let data = try JSONEncoder().encode(existingItems)
            try data.write(to: filePath)
            
            logger.debug("Saved \(items.count) items to local file: \(fileName)")
        } catch {
            errorHandler.handle(error, context: "Local file batch save", userFacing: false)
        }
    }
    
    private func loadFromLocalFile<T: Codable>(fileName: String, type: T.Type) async -> [T] {
        let filePath = getFilePath(fileName: fileName)
        
        do {
            if fileManager.fileExists(atPath: filePath.path) {
                let data = try Data(contentsOf: filePath)
                let items = try JSONDecoder().decode([T].self, from: data)
                logger.debug("Loaded \(items.count) items from local file: \(fileName)")
                return items
            }
        } catch {
            errorHandler.handle(error, context: "Local file load", userFacing: false)
        }
        
        return []
    }
    
    // MARK: - Offline Queue Operations
    
    private func queueForFirebase(_ record: LocationRecord) async {
        let operation = OfflineOperation(
            id: UUID().uuidString,
            type: .locationRecord,
            data: try! JSONEncoder().encode(record),
            timestamp: Date(),
            retryCount: 0
        )
        
        offlineQueue.append(operation)
        saveOfflineQueue()
        
        // Try to process immediately
        await processOfflineQueue()
    }
    
    private func queueBatchForFirebase(_ records: [LocationRecord]) async {
        for record in records {
            await queueForFirebase(record)
        }
    }
    
    private func queueTripForFirebase(_ trip: Trip) async {
        let operation = OfflineOperation(
            id: UUID().uuidString,
            type: .trip,
            data: try! JSONEncoder().encode(trip),
            timestamp: Date(),
            retryCount: 0
        )
        
        offlineQueue.append(operation)
        saveOfflineQueue()
        
        // Try to process immediately
        await processOfflineQueue()
    }
    
    private func processOfflineQueue() async {
        guard !offlineQueue.isEmpty else { return }
        
        let operations = offlineQueue.filter { operation in
            let timeSinceCreation = Date().timeIntervalSince(operation.timestamp)
            return timeSinceCreation > 5.0 // Wait 5 seconds before retry
        }
        
        for operation in operations {
            await processOfflineOperation(operation)
        }
    }
    
    private func processOfflineOperation(_ operation: OfflineOperation) async {
        do {
            switch operation.type {
            case .locationRecord:
                let record = try JSONDecoder().decode(LocationRecord.self, from: operation.data)
                await saveToFirebase(record)
            case .trip:
                let trip = try JSONDecoder().decode(Trip.self, from: operation.data)
                await saveTripToFirebase(trip)
            }
            
            // Remove successful operation
            offlineQueue.removeAll { $0.id == operation.id }
            saveOfflineQueue()
            
        } catch {
            // Increment retry count
            if let index = offlineQueue.firstIndex(where: { $0.id == operation.id }) {
                offlineQueue[index].retryCount += 1
                
                // Remove if too many retries
                if offlineQueue[index].retryCount >= 3 {
                    offlineQueue.remove(at: index)
                }
                
                saveOfflineQueue()
            }
            
            await errorHandler.handleAsync(error, context: "Offline operation processing", userFacing: false)
        }
    }
    
    private func loadOfflineQueue() {
        if let data = userDefaults.data(forKey: offlineQueueKey),
           let queue = try? JSONDecoder().decode([OfflineOperation].self, from: data) {
            offlineQueue = queue
            logger.info("Loaded \(queue.count) offline operations")
        }
    }
    
    private func saveOfflineQueue() {
        if let data = try? JSONEncoder().encode(offlineQueue) {
            userDefaults.set(data, forKey: offlineQueueKey)
        }
    }
    
    // MARK: - Batch Processing
    
    private func setupBatchTimer() {
        batchTimer = Timer.scheduledTimer(withTimeInterval: batchTimeout, repeats: true) { [weak self] _ in
            Task {
                await self?.processPendingBatches()
            }
        }
    }
    
    private func processPendingBatches() async {
        if !pendingLocationRecords.isEmpty {
            await saveLocationRecords(pendingLocationRecords)
            pendingLocationRecords.removeAll()
        }
        
        if !pendingTrips.isEmpty {
            for trip in pendingTrips {
                await saveTrip(trip)
            }
            pendingTrips.removeAll()
        }
    }
    
    // MARK: - Data Management
    
    func clearLocalData(deviceId: String) async {
        let locationFile = getFilePath(fileName: "location_records_\(deviceId).json")
        let tripFile = getFilePath(fileName: "trips_\(deviceId).json")
        
        do {
            if fileManager.fileExists(atPath: locationFile.path) {
                try fileManager.removeItem(at: locationFile)
            }
            if fileManager.fileExists(atPath: tripFile.path) {
                try fileManager.removeItem(at: tripFile)
            }
            logger.info("Cleared local data for device: \(deviceId)")
        } catch {
            errorHandler.handle(error, context: "Clear local data", userFacing: false)
        }
    }
    
    func getStorageStatistics() -> StorageStatistics {
        let documentsDirectory = getDocumentsDirectory()
        var totalSize: Int64 = 0
        var fileCount = 0
        
        do {
            let files = try fileManager.contentsOfDirectory(at: documentsDirectory, includingPropertiesForKeys: [.fileSizeKey])
            for file in files {
                if file.pathExtension == "json" {
                    let attributes = try fileManager.attributesOfItem(atPath: file.path)
                    if let size = attributes[.size] as? Int64 {
                        totalSize += size
                        fileCount += 1
                    }
                }
            }
        } catch {
            logger.error("Error calculating storage statistics: \(error.localizedDescription)")
        }
        
        return StorageStatistics(
            totalSize: totalSize,
            fileCount: fileCount,
            offlineQueueSize: offlineQueue.count
        )
    }
    
    // MARK: - Network Status
    
    func setNetworkAvailable(_ available: Bool) {
        if available {
            Task {
                await processOfflineQueue()
            }
        }
    }
}

// MARK: - Supporting Types

struct OfflineOperation: Codable {
    let id: String
    let type: OperationType
    let data: Data
    let timestamp: Date
    var retryCount: Int
    
    enum OperationType: String, Codable {
        case locationRecord
        case trip
    }
}

struct StorageStatistics {
    let totalSize: Int64
    let fileCount: Int
    let offlineQueueSize: Int
    
    var formattedSize: String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: totalSize)
    }
}

// MARK: - Global Instance

let dataPersistenceManager = DataPersistenceManager.shared
