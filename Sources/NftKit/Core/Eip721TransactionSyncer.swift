import BigInt
import EvmKit

class Eip721TransactionSyncer {
    private let provider: ITransactionProvider
    private let storage: Storage

    weak var delegate: ITransactionSyncerDelegate?

    init(provider: ITransactionProvider, storage: Storage) {
        self.provider = provider
        self.storage = storage
    }

    private func handle(transactions: [ProviderEip721Transaction]) {
        guard !transactions.isEmpty else {
            return
        }

        let events = transactions.map { tx in
            Eip721Event(
                hash: tx.hash,
                blockNumber: tx.blockNumber,
                contractAddress: tx.contractAddress,
                from: tx.from,
                to: tx.to,
                tokenId: tx.tokenId,
                tokenName: tx.tokenName,
                tokenSymbol: tx.tokenSymbol,
                tokenDecimal: tx.tokenDecimal
            )
        }

        try? storage.save(eip721Events: events)

        let nfts = Set<Nft>(events.map { event in
            Nft(
                type: .eip721,
                contractAddress: event.contractAddress,
                tokenId: event.tokenId,
                tokenName: event.tokenName
            )
        })

        delegate?.didSync(nfts: Array(nfts), type: .eip721)
    }
}

extension Eip721TransactionSyncer: ITransactionSyncer {
    func transactions() async throws -> ([Transaction], Bool) {
        let lastBlockNumber = try storage.lastEip721Event()?.blockNumber ?? 0
        let initial = lastBlockNumber == 0

        do {
            let transactions = try await provider.eip721Transactions(startBlock: lastBlockNumber + 1)

            handle(transactions: transactions)

            let array = transactions.map { tx in
                Transaction(
                    hash: tx.hash,
                    timestamp: tx.timestamp,
                    isFailed: false,
                    blockNumber: tx.blockNumber,
                    transactionIndex: tx.transactionIndex,
                    nonce: tx.nonce,
                    gasPrice: tx.gasPrice,
                    gasLimit: tx.gasLimit,
                    gasUsed: tx.gasUsed
                )
            }

            return (array, initial)
        } catch {
            return ([], initial)
        }
    }
}
