import BigInt
import EvmKit
import Foundation

class Eip1155SetApprovalForAllMethodFactory: IContractMethodFactory {
    let methodId: Data = ContractMethodHelper.methodId(signature: Eip1155SetApprovalForAllMethod.methodSignature)

    func createMethod(inputArguments: Data) throws -> ContractMethod {
        Eip1155SetApprovalForAllMethod(
            operator: Address(raw: inputArguments[12 ..< 32]),
            approved: BigUInt(inputArguments[32 ..< 64]) != 0
        )
    }
}
