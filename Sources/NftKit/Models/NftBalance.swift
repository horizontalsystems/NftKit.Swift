import BigInt
import EvmKit
import GRDB

public class NftBalance: Record {
    public let nft: Nft
    public var balance: Int
    var synced: Bool

    init(nft: Nft, balance: Int, synced: Bool) {
        self.nft = nft
        self.balance = balance
        self.synced = synced

        super.init()
    }

    override public class var databaseTableName: String {
        "nftBalances"
    }

    enum Columns: String, ColumnExpression {
        case type
        case contractAddress
        case tokenId
        case tokenName
        case balance
        case synced
    }

    public required init(row: Row) throws {
        nft = Nft(
            type: row[Columns.type],
            contractAddress: Address(raw: row[Columns.contractAddress]),
            tokenId: row[Columns.tokenId],
            tokenName: row[Columns.tokenName]
        )
        balance = row[Columns.balance]
        synced = row[Columns.synced]

        try super.init(row: row)
    }

    override public func encode(to container: inout PersistenceContainer) throws {
        container[Columns.type] = nft.type
        container[Columns.contractAddress] = nft.contractAddress.raw
        container[Columns.tokenId] = nft.tokenId
        container[Columns.tokenName] = nft.tokenName
        container[Columns.balance] = balance
        container[Columns.synced] = synced
    }
}
