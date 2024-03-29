import BigInt
import EvmKit

class Eip721SetApprovalForAllMethod: ContractMethod {
    static let methodSignature = "setApprovalForAll(address,bool)"

    let `operator`: Address
    let approved: Bool

    init(operator: Address, approved: Bool) {
        self.operator = `operator`
        self.approved = approved

        super.init()
    }

    override var methodSignature: String { Self.methodSignature }
    override var arguments: [Any] { [`operator`, approved] }
}
