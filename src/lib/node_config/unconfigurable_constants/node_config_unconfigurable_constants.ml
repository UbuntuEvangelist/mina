(* FIXME: These should be configurable. *)

(** limits on Zkapp_command.t size
    10.26*np + 10.08*n2 + 9.14*n1 < 69.45
    where np: number of single proof updates
    n2: number of pairs of signed/no-auth update
    n1: number of single signed/no-auth update
    and their coefficients representing the cost
  The formula was generated based on benchmarking data conducted on bare
  metal i9 processor with room to include lower spec.
  69.45 was the total time for a combination of updates that was considered
  acceptable.
  The method used to estimate the cost was linear least squares.
*)

let zkapp_proof_update_cost = 10.26

let zkapp_signed_pair_update_cost = 10.08

let zkapp_signed_single_update_cost = 9.14

let zkapp_transaction_cost_limit = 69.45

let max_event_elements = 100

let max_action_elements = 100

let zkapp_cmd_limit_hardcap = 128

let zkapps_disabled = false