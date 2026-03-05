import Foundation
import MultipeerConnectivity

class SonarDuelNetworkManager: NSObject, ObservableObject {
    static let serviceType = "sonar-duel"

    @Published var isHost = false
    @Published var isConnected = false
    @Published var availableHosts: [MCPeerID] = []
    @Published var connectedPeerName: String?
    @Published var didDisconnect = false

    private var peerID: MCPeerID
    private var session: MCSession
    private var advertiser: MCNearbyServiceAdvertiser?
    private var browser: MCNearbyServiceBrowser?

    var onMessageReceived: ((NetworkMessage) -> Void)?

    override init() {
        let displayName = UIDevice.current.name
        self.peerID = MCPeerID(displayName: displayName)
        self.session = MCSession(peer: peerID, securityIdentity: nil, encryptionPreference: .none)
        super.init()
        self.session.delegate = self
    }

    // MARK: - Host

    func startHosting() {
        isHost = true
        advertiser = MCNearbyServiceAdvertiser(
            peer: peerID,
            discoveryInfo: nil,
            serviceType: Self.serviceType
        )
        advertiser?.delegate = self
        advertiser?.startAdvertisingPeer()
    }

    func stopHosting() {
        advertiser?.stopAdvertisingPeer()
        advertiser = nil
    }

    // MARK: - Join

    func startBrowsing() {
        isHost = false
        browser = MCNearbyServiceBrowser(peer: peerID, serviceType: Self.serviceType)
        browser?.delegate = self
        browser?.startBrowsingForPeers()
    }

    func stopBrowsing() {
        browser?.stopBrowsingForPeers()
        browser = nil
    }

    func joinHost(_ host: MCPeerID) {
        browser?.invitePeer(host, to: session, withContext: nil, timeout: 10)
    }

    // MARK: - Communication

    func send(_ message: NetworkMessage) {
        guard !session.connectedPeers.isEmpty else { return }
        do {
            let data = try JSONEncoder().encode(message)
            try session.send(data, toPeers: session.connectedPeers, with: .reliable)
        } catch {
            print("Send error: \(error)")
        }
    }

    func disconnect() {
        send(.disconnect)
        session.disconnect()
        stopHosting()
        stopBrowsing()
        DispatchQueue.main.async {
            self.isConnected = false
            self.connectedPeerName = nil
            self.availableHosts.removeAll()
        }
    }

    func reset() {
        disconnect()
        didDisconnect = false
    }
}

// MARK: - MCSessionDelegate

extension SonarDuelNetworkManager: MCSessionDelegate {
    func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        DispatchQueue.main.async {
            switch state {
            case .connected:
                self.isConnected = true
                self.connectedPeerName = peerID.displayName
                self.stopHosting()
                self.stopBrowsing()
            case .notConnected:
                if self.isConnected {
                    self.isConnected = false
                    self.connectedPeerName = nil
                    self.didDisconnect = true
                }
            case .connecting:
                break
            @unknown default:
                break
            }
        }
    }

    func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        guard let message = try? JSONDecoder().decode(NetworkMessage.self, from: data) else { return }
        DispatchQueue.main.async {
            self.onMessageReceived?(message)
        }
    }

    func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {}
    func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {}
    func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {}
}

// MARK: - MCNearbyServiceAdvertiserDelegate

extension SonarDuelNetworkManager: MCNearbyServiceAdvertiserDelegate {
    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didReceiveInvitationFromPeer peerID: MCPeerID, withContext context: Data?, invitationHandler: @escaping (Bool, MCSession?) -> Void) {
        // Auto-accept the first connection
        invitationHandler(true, session)
    }

    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didNotStartAdvertisingPeer error: Error) {
        print("Advertise error: \(error)")
    }
}

// MARK: - MCNearbyServiceBrowserDelegate

extension SonarDuelNetworkManager: MCNearbyServiceBrowserDelegate {
    func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String: String]?) {
        DispatchQueue.main.async {
            if !self.availableHosts.contains(where: { $0.displayName == peerID.displayName }) {
                self.availableHosts.append(peerID)
            }
        }
    }

    func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
        DispatchQueue.main.async {
            self.availableHosts.removeAll { $0.displayName == peerID.displayName }
        }
    }

    func browser(_ browser: MCNearbyServiceBrowser, didNotStartBrowsingForPeers error: Error) {
        print("Browse error: \(error)")
    }
}
