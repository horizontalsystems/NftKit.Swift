import BigInt
import Combine
import EvmKit
import Foundation

public class Kit {
    private let evmKit: EvmKit.Kit
    private let balanceManager: BalanceManager
    private let balanceSyncManager: BalanceSyncManager
    private let transactionManager: TransactionManager
    private let storage: Storage
    private var cancellables = Set<AnyCancellable>()

    init(evmKit: EvmKit.Kit, balanceManager: BalanceManager, balanceSyncManager: BalanceSyncManager, transactionManager: TransactionManager, storage: Storage) {
        self.evmKit = evmKit
        self.balanceManager = balanceManager
        self.balanceSyncManager = balanceSyncManager
        self.transactionManager = transactionManager
        self.storage = storage

        evmKit.syncStatePublisher
            .sink { [weak self] in
                self?.onUpdateSyncState(syncState: $0)
            }
            .store(in: &cancellables)
    }

    private func onUpdateSyncState(syncState: EvmKit.SyncState) {
        switch syncState {
        case .synced:
            balanceSyncManager.sync()
        case .syncing:
            ()
        case let .notSynced(error):
            ()
        }
    }
}

public extension Kit {
    func sync() {
        if case .synced = evmKit.syncState {
            balanceSyncManager.sync()
        }
    }

    var nftBalances: [NftBalance] {
        balanceManager.nftBalances
    }

    var nftBalancesPublisher: AnyPublisher<[NftBalance], Never> {
        balanceManager.$nftBalances
    }

    func nftBalance(contractAddress: Address, tokenId: BigUInt) -> NftBalance? {
        balanceManager.nftBalance(contractAddress: contractAddress, tokenId: tokenId)
    }

    func transferEip721TransactionData(contractAddress: Address, to: Address, tokenId: BigUInt) -> TransactionData {
        transactionManager.transferEip721TransactionData(contractAddress: contractAddress, to: to, tokenId: tokenId)
    }

    func transferEip1155TransactionData(contractAddress: Address, to: Address, tokenId: BigUInt, value: BigUInt) -> TransactionData {
        transactionManager.transferEip1155TransactionData(contractAddress: contractAddress, to: to, tokenId: tokenId, value: value)
    }
}

extension Kit: ITransactionSyncerDelegate {
    func didSync(nfts: [Nft], type: NftType) {
        balanceManager.didSync(nfts: nfts, type: type)
    }
}

public extension Kit {
    func addEip721TransactionSyncer() {
        let syncer = Eip721TransactionSyncer(provider: evmKit.transactionProvider, storage: storage)
        syncer.delegate = self
        evmKit.add(transactionSyncer: syncer)
    }

    func addEip1155TransactionSyncer() {
        let syncer = Eip1155TransactionSyncer(provider: evmKit.transactionProvider, storage: storage)
        syncer.delegate = self
        evmKit.add(transactionSyncer: syncer)
    }

    func addEip721Decorators() {
        evmKit.add(methodDecorator: Eip721MethodDecorator(contractMethodFactories: Eip721ContractMethodFactories.shared))
        evmKit.add(eventDecorator: Eip721EventDecorator(userAddress: evmKit.address, storage: storage))
        evmKit.add(transactionDecorator: Eip721TransactionDecorator(userAddress: evmKit.address))
    }

    func addEip1155Decorators() {
        evmKit.add(methodDecorator: Eip1155MethodDecorator(contractMethodFactories: Eip1155ContractMethodFactories.shared))
        evmKit.add(eventDecorator: Eip1155EventDecorator(userAddress: evmKit.address, storage: storage))
        evmKit.add(transactionDecorator: Eip1155TransactionDecorator(userAddress: evmKit.address))
    }
}

public extension Kit {
    static func instance(evmKit: EvmKit.Kit) throws -> Kit {
        let storage = try Storage(databaseDirectoryUrl: dataDirectoryUrl(), databaseFileName: "storage-\(evmKit.uniqueId)")

        let dataProvider = DataProvider(evmKit: evmKit)
        let balanceSyncManager = BalanceSyncManager(address: evmKit.address, storage: storage, dataProvider: dataProvider)
        let balanceManager = BalanceManager(storage: storage, syncManager: balanceSyncManager)

        balanceSyncManager.delegate = balanceManager

        let transactionManager = TransactionManager(evmKit: evmKit)

        let kit = Kit(
            evmKit: evmKit,
            balanceManager: balanceManager,
            balanceSyncManager: balanceSyncManager,
            transactionManager: transactionManager,
            storage: storage
        )

        return kit
    }

    static func clear(exceptFor excludedFiles: [String]) throws {
        let fileManager = FileManager.default
        let fileUrls = try fileManager.contentsOfDirectory(at: dataDirectoryUrl(), includingPropertiesForKeys: nil)

        for filename in fileUrls {
            if !excludedFiles.contains(where: { filename.lastPathComponent.contains($0) }) {
                try fileManager.removeItem(at: filename)
            }
        }
    }

    private static func dataDirectoryUrl() throws -> URL {
        let fileManager = FileManager.default

        let url = try fileManager
            .url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            .appendingPathComponent("nft-kit", isDirectory: true)

        try fileManager.createDirectory(at: url, withIntermediateDirectories: true)

        return url
    }
}
