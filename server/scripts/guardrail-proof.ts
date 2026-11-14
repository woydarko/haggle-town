// Testnet guardrail proof: node --env-file=../.env scripts/guardrail-proof.ts [userId]
// Sends a deal the Woodcutter really signed, at 1 coin for pine (far under the floor in pricing.rs).
// The contract must refuse it with PriceOutOfRoom: a valid AI signature cannot buy a price outside the rules.
import { loadConfig } from "../src/config.ts";
import { openDb } from "../src/db/db.ts";
import { createNearChain, ChainError } from "../src/chain/near.ts";
import { createQueue } from "../src/chain/queue.ts";
import { Gather } from "../src/game/gather.ts";
import { Players } from "../src/game/players.ts";
import { signDeal, newNonce, type ChainDeal } from "../src/haggle/deal.ts";

const config = loadConfig();
const db = openDb(":memory:");
const chain = createNearChain(config);
const queue = createQueue();
const players = new Players(db, chain, queue, new Gather(db, chain, queue));

const player = `roblox:${process.argv[2] ?? "999003"}`;
await players.join(player, "guardrail-proof");

const deal: ChainDeal = {
  merchant: `woodcutter.${config.CONTRACT_ID}`,
  player,
  good: "wood_pine",
  qty: 1,
  unit_price: "1",
  side: "buy",
  nonce: String(newNonce()),
  expires_at_ns: (BigInt(Date.now() + 60_000) * 1_000_000n).toString(),
};
try {
  await chain.call("settle_deal", { deal, merchant_sig: signDeal(deal, config.WOODCUTTER_PRIVATE_KEY) });
  console.error("PROOF FAILED: the contract accepted an out-of-room price");
  process.exit(1);
} catch (e) {
  if (!(e instanceof ChainError) || e.code !== "PriceOutOfRoom") throw e;
  console.log(`PROOF OK: PriceOutOfRoom, tx ${e.txHash}`);
  console.log(`https://testnet.nearblocks.io/txns/${e.txHash}`);
}
