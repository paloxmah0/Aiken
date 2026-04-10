use aiken/collection/dict
use aiken/collection/list
use aiken/crypto.{VerificationKeyHash}
use cardano/assets.{PolicyId}
use cardano/transaction.{Input, OutputReference, Transaction, TransactionId}

pub type Datum {
  signers: List<VerificationKeyHash>,
  threshold: Int,
}

pub type Action {
  Mint
  Burn
  Execute
  UpdateSigners(List<VerificationKeyHash>, Int)
}

fn count_valid_signers(
  signers: List<VerificationKeyHash>,
  tx: Transaction,
) -> Int {
  list.count(signers, fn(pkh) { list.has(tx.extra_signatories, pkh) })
}

validator vault(utxo_ref: OutputReference) {
  spend(datum: Option<Datum>, redeemer: Action, tx: Transaction, _ref) {
    when datum is {
      None -> fail
      Some(datum) -> {
        let signers = datum.signers
        let threshold = datum.threshold
        let signers_count = count_valid_signers(signers, tx)
        let authorized = signers_count >= threshold
        when redeemer is {
          Execute -> authorized
          UpdateSigners(new_signers, new_threshold) ->
            authorized && new_threshold > 0 && new_threshold <= list.length(
              new_signers,
            )
          _ -> fail
        }
      }
    }
  }

  mint(redeemer: Action, policy_id: PolicyId, tx: Transaction) {
    let must_spend_utxo =
      list.any(tx.inputs, fn(inputs) { inputs.output_reference == utxo_ref })
    let minted_tokens =
      tx.mint
        |> assets.tokens(policy_id)

    let correct_asset_count = dict.size(minted_tokens) == 1
    let correct_quantity =
      list.all(dict.values(minted_tokens), fn(qty) { qty == 1 })

    when redeemer is {
      Mint -> must_spend_utxo && correct_asset_count && correct_quantity
      Burn -> must_spend_utxo && correct_asset_count && correct_quantity
      _ -> fail
    }
  }

  else(_) {
    fail
  }
}
