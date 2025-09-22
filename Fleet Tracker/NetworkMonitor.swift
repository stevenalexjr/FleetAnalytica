//
//  NetworkMonitor.swift
//  Fleet Tracker
//
//  Created by Steven Alexander on 9/20/25.
//

import Foundation
import Network
import Combine

// MARK: - Network Status

enum NetworkStatus {
    case connected
    case disconnected
    case unknown
}

// MARK: - Network Monitor

class NetworkMonitor: ObservableObject {
    static let shared = NetworkMonitor()
    
    @Published var isConnected: Bool = false
    @Published var connectionType: ConnectionType = .unknown
    @Published var networkStatus: NetworkStatus = .unknown
    
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "NetworkMonitor")
    private let logger = Logger.shared
    
    private init() {
        startMonitoring()
    }
    
    deinit {
        monitor.cancel()
    }
    
    // MARK: - Monitoring
    
    private func startMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                self?.updateNetworkStatus(path)
            }
        }
        
        monitor.start(queue: queue)
        logger.info("Network monitoring started")
    }
    
    private func updateNetworkStatus(_ path: NWPath) {
        let wasConnected = isConnected
        isConnected = path.status == .satisfied
        
        // Update connection type
        if path.usesInterfaceType(.wifi) {
            connectionType = .wifi
        } else if path.usesInterfaceType(.cellular) {
            connectionType = .cellular
        } else if path.usesInterfaceType(.wiredEthernet) {
            connectionType = .ethernet
        } else {
            connectionType = .unknown
        }
        
        // Update network status
        switch path.status {
        case .satisfied:
            networkStatus = .connected
        case .unsatisfied:
            networkStatus = .disconnected
        case .requiresConnection:
            networkStatus = .disconnected
        @unknown default:
            networkStatus = .unknown
        }
        
        // Log status changes
        if wasConnected != isConnected {
            if isConnected {
                logger.info("Network connected via \(connectionType.rawValue)")
                dataPersistenceManager.setNetworkAvailable(true)
            } else {
                logger.warning("Network disconnected")
                dataPersistenceManager.setNetworkAvailable(false)
            }
        }
    }
    
    // MARK: - Public Methods
    
    func getConnectionQuality() -> ConnectionQuality {
        switch connectionType {
        case .wifi:
            return .excellent
        case .ethernet:
            return .excellent
        case .cellular:
            return .good
        case .unknown:
            return .poor
        }
    }
    
    func isConnectionStable() -> Bool {
        return isConnected && connectionType != .unknown
    }
    
    func shouldSyncToCloud() -> Bool {
        return isConnected && connectionType != .cellular
    }
}

// MARK: - Connection Type

enum ConnectionType: String, CaseIterable {
    case wifi = "Wi-Fi"
    case cellular = "Cellular"
    case ethernet = "Ethernet"
    case unknown = "Unknown"
    
    var icon: String {
        switch self {
        case .wifi:
            return "wifi"
        case .cellular:
            return "antenna.radiowaves.left.and.right"
        case .ethernet:
            return "cable.connector"
        case .unknown:
            return "questionmark.circle"
        }
    }
}

// MARK: - Connection Quality

enum ConnectionQuality: String, CaseIterable {
    case excellent = "Excellent"
    case good = "Good"
    case fair = "Fair"
    case poor = "Poor"
    
    var color: String {
        switch self {
        case .excellent:
            return "green"
        case .good:
            return "blue"
        case .fair:
            return "orange"
        case .poor:
            return "red"
        }
    }
}

// MARK: - Global Instance

let networkMonitor = NetworkMonitor.shared
