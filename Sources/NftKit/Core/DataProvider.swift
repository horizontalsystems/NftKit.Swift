import BigInt
import EvmKit
import HsExtensions

class DataProvider {
    private let evmKit: EvmKit.Kit

    init(evmKit: EvmKit.Kit) {
        self.evmKit = evmKit
    }
}

extension DataProvider {
    func getEip721Owner(contractAddress: Address, tokenId: BigUInt) async throws -> Address {
        let data = try await evmKit.fetchCall(contractAddress: contractAddress, data: Eip721OwnerOfMethod(tokenId: tokenId).encodedABI())
        return Address(raw: data)
    }

    func getEip1155Balance(contractAddress: Address, owner: Address, tokenId: BigUInt) async throws -> Int {
        let data = try await evmKit.fetchCall(contractAddress: contractAddress, data: Eip1155BalanceOfMethod(owner: owner, tokenId: tokenId).encodedABI())

        guard let value = BigUInt(data.prefix(32).hs.hex, radix: 16) else {
            throw ContractCallError.invalidBalanceData
        }

        return Int(value)
    }
}

extension DataProvider {
    enum ContractCallError: Error {
        case invalidBalanceData
    }
}
