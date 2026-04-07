use aiken/collection/dict
use aiken/collection/list
use cardano/assets.{PolicyId}
use cardano/transaction.{Input, OutputReference, Transaction}

pub type Action {
  Mint
  Cancel
}

validator minting(utxo_ref: OutputReference) {
  mint(redeemer: Action, policy_id: PolicyId, tx: Transaction) {
    let minted_tokens =
      tx.mint
        |> assets.tokens(policy_id)

    let correct_asset_count = dict.size(minted_tokens) == 1

    let correct_quantity =
      list.all(dict.values(minted_tokens), fn(qty) { qty == 1 })

    let authorized_signer =
      #"abcd1234abcd1234abcd1234abcd1234abcd1234abcd1234abcd123400"

    let must_be_signed = list.has(tx.extra_signatories, authorized_signer)

    let no_burning = list.all(dict.values(minted_tokens), fn(qty) { qty > 0 })

    when redeemer is {
      Mint -> {
        let must_spend_utxo =
          list.any(tx.inputs, fn(input) { input.output_reference == utxo_ref })
        must_spend_utxo && correct_asset_count && correct_quantity && must_be_signed && no_burning
      }
      Cancel -> must_be_signed
    }
  }

  else(_) {
    fail
  }
}
