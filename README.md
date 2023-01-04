# NftKit.Swift

`NftKit.Swift` extends `EvmKit.Swift` to support `EIP721` and `EIP1155` non-fungible tokens(NFT).

## Features

- Supports ERC-721 and ERC-1155 NFT smart contracts
- Synchronization of NFTs owned by the user
- Send/Receive NFTs

## Usage

### Initialization

```swift
import EvmKit
import NftKit

let evmKit = try Kit.instance(
	address: try EvmKit.Address(hex: "0x..user..address.."),
	chain: .ethereum,
	rpcSource: .ethereumInfuraWebsocket(projectId: "...", projectSecret: "..."),
	transactionSource: .ethereumEtherscan(apiKey: "..."),
	walletId: "unique_wallet_id",
	minLogLevel: .error
)

let nftKit = try NftKit.Kit.instance(evmKit: evmKit)

// Decorators are needed to detect transactions as `Uniswap` transactions
nftKit.addEip721Decorators()
nftKit.addEip1155Decorators()

// Transaction syncers are needed to pull the NFT transfer transactions from Etherscan
nftKit.addEip721TransactionSyncer()
nftKit.addEip1155TransactionSyncer()
```

### Get NFTs owned by the user

```swift
let balances = nftKit.balances

for nftBalance in balances {
	print("---- \(nftBalance.balance) pieces of \(nftBalance.nft.name) ---")
	print("Contract Address: \(nftBalance.nft.contractAddress.eip55)")
	print("TokenID: \(nftBalance.nft.tokenId.description)")
}
```


### Send an NFT

```swift
// Get Signer object
let seed = Mnemonic.seed(mnemonic: ["mnemonic", "words", ...])!
let signer = try Signer.instance(seed: seed, chain: .ethereum)

let nftContractAddress = try EvmKit.Address(hex: "0x..contract..address")
let tokenId = BigUInt("234123894712031638516723498")
let to = try EvmKit.Address(hex: "0x..recipient..address")
let gasPrice = GasPrice.legacy(gasPrice: 50_000_000_000)

// Construct a TransactionData
let transactionData = nftKit.transferEip721TransactionData(contractAddress: nftContractAddress, to: to, tokenId: tokenId)

// Estimate gas for the transaction
let estimateGasSingle = evmKit.estimateGas(transactionData: transactionData, gasPrice: gasPrice)

// Generate a raw transaction which is ready to be signed
let rawTransactionSingle = estimateGasSingle.flatMap { estimatedGasLimit in
    evmKit.rawTransaction(transactionData: transactionData, gasPrice: gasPrice, gasLimit: estimatedGasLimit)
}

let sendSingle = rawTransactionSingle.flatMap { rawTransaction in
    // Sign the transaction
    let signature = try signer.signature(rawTransaction: rawTransaction)
    
    // Send the transaction to RPC node
    return evmKit.sendSingle(rawTransaction: rawTransaction, signature: signature)
}


let disposeBag = DisposeBag()

sendSingle
    .subscribe(
        onSuccess: { fullTransaction in
            let transaction = fullTransaction.transaction
            print("Transaction sent: \(transaction.hash.hs.hexString)")
        }, onError: { error in
            print("Send failed: \(error)")
        }
    )
    .disposed(by: disposeBag)
```


## Installation

### Swift Package Manager

```swift
dependencies: [
    .package(url: "https://github.com/horizontalsystems/NftKit.Swift.git", .upToNextMajor(from: "1.0.0"))
]
```

## License

The `NftKit.Swift` toolkit is open source and available under the terms of the [MIT License](https://github.com/horizontalsystems/ethereum-kit-ios/blob/master/LICENSE).

