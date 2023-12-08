import BigInt
import EvmKit
import Foundation
import HsExtensions

class BalanceSyncManager {
    private let address: Address
    private let storage: Storage
    private let dataProvider: DataProvider
    private var tasks = Set<AnyTask>()

    private var syncing = false
    private var syncRequested = false

    private let queue = DispatchQueue(label: "io.horizontal-systems.nft-kit.balance-sync-manager", qos: .userInitiated)

    weak var delegate: IBalanceSyncManagerDelegate?

    init(address: Address, storage: Storage, dataProvider: DataProvider) {
        self.address = address
        self.storage = storage
        self.dataProvider = dataProvider
    }

    private func _finishSync() {
        syncing = false

        if syncRequested {
            syncRequested = false
            sync()
        }
    }

    private func _handle(nftBalances: [Nft: Int?]) {
        var balanceInfos = [(Nft, Int)]()

        for (nft, balance) in nftBalances {
            if let balance {
//                print("Synced balance for \(nftBalance.nft.tokenName) - \(nftBalance.nft.contractAddress) - \(nftBalance.nft.tokenId) - \(balance)")
                balanceInfos.append((nft, balance))
            } else {
                print("Failed to sync balance for \(nft.tokenName) - \(nft.contractAddress) - \(nft.tokenId)")
            }
        }

        try? storage.setSynced(balanceInfos: balanceInfos)

        delegate?.didFinishSyncBalances()

        _finishSync()
    }

    private func handle(nftBalances: [Nft: Int?]) {
        queue.async {
            self._handle(nftBalances: nftBalances)
        }
    }

    private func _syncBalances(nfts: [Nft]) async {
        let balances = await withTaskGroup(of: (Nft, Int?).self) { group in
            for nft in nfts {
                group.addTask {
                    await (nft, try? self.balance(nft: nft))
                }
            }

            var balances = [Nft: Int?]()

            for await (nft, nftBalance) in group {
                balances[nft] = nftBalance
            }

            return balances
        }

        handle(nftBalances: balances)
    }

    private func _sync() throws {
        if syncing {
            syncRequested = true
            return
        }

        syncing = true

        let nftBalances = try storage.nonSyncedNftBalances()

        guard !nftBalances.isEmpty else {
            _finishSync()
            return
        }

//        print("NON SYNCED: \(nftBalances.count)")

        Task { [weak self] in
            await self?._syncBalances(nfts: nftBalances.map(\.nft))
        }.store(in: &tasks)
    }

    private func balance(nft: Nft) async throws -> Int {
        let address = address

        switch nft.type {
        case .eip721:
            do {
                let owner = try await dataProvider.getEip721Owner(contractAddress: nft.contractAddress, tokenId: nft.tokenId)
                return owner == address ? 1 : 0
            } catch {
                if case JsonRpcResponse.ResponseError.rpcError = error {
                    return 0
                }

                throw error
            }
        case .eip1155:
            return try await dataProvider.getEip1155Balance(contractAddress: nft.contractAddress, owner: address, tokenId: nft.tokenId)
        }
    }
}

extension BalanceSyncManager {
    func sync() {
        queue.async {
            try? self._sync()
        }
    }
}
