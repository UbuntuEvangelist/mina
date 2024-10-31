## Replayer component test

This folder holds static data which is used when testing replayer component. Name 'component' is used in context of test since it is not na unit tests but also not interfere with other mina components, so it cannot be called integration test. Basically test production version of replayer against manually prepared data and input config file using command:

```
mina-replayer --archive-uri {connection_string} --input-file input.json
```

It expects success

### Regenerate data

Data generation is still manual process. Mina local network script (./script/mina-local-network/mina-local-network.sh) can be used to bootstrap small network and generate archive data. For example below command is usually used:

```
./scripts/mina-local-network/mina-local-network.sh -a -r -pu postgres -ppw postgres -zt -vt
```

where:
- `-a` run archive (it will automatically create 'archive' schema)
- `-r` removes any artifacts from previous run to have clear situation
- `-pu -ppw` are database connection parameters
- `-zt` ran zkapp transactions
- `-vt` ran simple value transfer transactions

> :warning: Prior to mina-local-network run you need to build mina, archive, zkapp_transaction, logproc apps

It is important to mention that properly generated archive data should have at least 10 canonical blocks as we run replayer tests only on canonical blocks.

After we are satisfied with data generation process. We can dump archive data and prepare input replayer file from genesis_ledger.json file from our local network

#### Full script

Disclaimer: I'm a nix user and has already setup nix on my machine

```bash
nix develop mina

DUNE_PROFILE=devnet dune build src/app/cli/src/mina.exe src/app/archive/archive.exe src/app/zkapp_test_transaction/zkapp_test_transaction.exe src/app/logproc/logproc.exe

psql -c 'CREATE DATABASE archive'
psql archive < ./src/app/archive/create_schema.sql
# set the password to postgres or change the `-ppw` option to agree with what you chose
echo "\\password postgres" | psql archive

DUNE_PROFILE=devnet ./scripts/mina-local-network/mina-local-network.sh -a -r -pu postgres -ppw postgres -zt -vt -lp
# This script will run forever
# In a seperate terminal run
watch 'psql archive -t -c  "select MAX(global_slot_since_genesis) from blocks"'
# This will tell you the current height of the chain
# You can stop the script when it's at least 10

# at this point you probably want to run this script to make the blocks canonical
./src/test/archive/sample_db/convert_chain_to_canonical.sh postgres://postgres:postgres@localhost:5432/archive

# replace precomputed_blocks.zip with whole mess
find ~/.mina-network -name 'precomputed_blocks.log' | xargs -I ! ./scripts/mina-local-network/split_precomputed_log.sh ! precomputed_blocks
rm ./src/test/archive/sample_db/precomputed_blocks.zip
zip -r ./src/test/archive/sample_db/precomputed_blocks.zip precomputed_blocks
rm -rf precomputed_blocks


# archive_db.sql
pg_dump -U postgres -d archive > ./src/test/archive/sample_db/archive_db.sql

# input file
cp ~/.mina-network/mina-local-network-2-1-1/genesis_ledger.json _tmp1.json
cat genesis_ledger.json | jq '.accounts' > _tmp2.json
echo '{ "genesis_ledger": { "accounts": '$(cat _tmp.json)' } }' | jq > _tmp3.json
NEW_HASH=$(psql archive -t -c  'SELECT state_hash from blocks where global_slot_since_genesis = (SELECT MAX(global_slot_since_genesis) from blocks)' | sed 's/^ *//')
cat _tmp3.json | jq '.+{"target_epoch_ledgers_state_hash": "'$NEW_HASH'"}' > ./src/test/archive/sample_db/replayer_input_file.json
rm _tmp*.json


```

#### Alternatives

As mentioned in previous section we need to have some canonical blocks in archive database. The more the better. However, with current value of K parameter (responsible for converting pending block into canonical) this process can take a lot of time (> 7hours). Fortunately there are alternative solutions  for this problem.

a) We can alter input config and use `target_epoch_ledgers_state_hash` property in replayer input file to inform replayer that we want to replay also pending blocks. Example:

```
{
    "target_epoch_ledgers_state_hash": "3NLbZ28M72eewCxYUCE3CwQo5c7wPzoiGcNC5Bbe8oEnrutXtZt9",
    "genesis_ledger": {
    "name": "release",
    "num_accounts": 250,
    "accounts": [
     {
      "pk": "B62qkamwHMkTvY3t9wu4Aw4LJTDJY4m6Sk48pJ2kSMtV1fxKP2SSzWq",
   .....

```

b) Convert pending chain to canonical blocks using helper script:

`
`./src/test/archive/sample_db/convert_chain_to_canonical.sh postgres://postgres:postgres@localhost:5432/archive`

As a result archive database will now have blocks which are a part of chain from genesis block to target block converted to canonical. All blocks which are not a part of mentioned chain and have height smaller than target blocks will be orphaned. Rest will be left intact as pending. DO NOT USE on production.

### Dependencies

Replayer component tests uses postgres database only. It need to be accessible from host machine


