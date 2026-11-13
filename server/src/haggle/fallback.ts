/** Merchant voices. The rule-based merchant picks from these banks (never repeating its last 3 lines to a player);
 *  the LLM gets `style` and `examples` as a voice guide. Copy rules: no chain words, no em dash. */
export type Persona = {
  name: string;
  style: string;
  examples: string[];
  hello: string[];
  accept: string[];
  counter: ((price: number) => string)[];
  annoyed: string[];
  refuse: string[];
  broke: string[];
  /** Round limit reached: the last quote stays on the table. */
  wrapUp: string[];
};

export const PERSONAS: Record<string, Persona> = {
  woodcutter: {
    name: "Woodcutter",
    style: "gruff, practical, few words, proud of honest work; jokes about his axe and splinters",
    examples: [
      "Twenty for oak? My axe would laugh at you. Thirty, and I'll throw in a splinter for free.",
      "Pile's taller than me today. Take five at twenty-four and help an old man out.",
      "Wood's thin this week. Thirty-five, not a coin less.",
    ],
    hello: [
      "Fresh-cut this morning. What are you after?",
      "Wood's stacked and dry. Make me an offer.",
      "You look like someone who needs timber. Talk.",
      "Mind the splinters. What do you need?",
      "Axe is sharp, pile is high. Go on.",
      "Pine, oak, maple. Name it and name a price.",
      "Don't just stare at the logs. Offer something.",
    ],
    accept: [
      "Fine. Deal.",
      "Done. Shake on it.",
      "Fair enough. It's yours.",
      "Can't argue with that. Deal.",
      "Alright, you've earned it. Done.",
      "That works. Load it up.",
    ],
    counter: [
      (p) => `${p} C each. Take it or leave it.`,
      (p) => `I can do ${p} C a piece. Not lower.`,
      (p) => `${p} C each, and that's me being soft.`,
      (p) => `Call it ${p} C each and we're square.`,
      (p) => `${p} C apiece. My axe won't go lower.`,
      (p) => `Make it ${p} C each and I'll stop grumbling.`,
    ],
    annoyed: [
      "That's an insult to my axe.",
      "Ha. You trying to rob a woodcutter?",
      "That price gave me splinters.",
      "Did you count the coins wrong?",
      "I've heard better offers from beavers.",
      "Not even close, friend.",
    ],
    refuse: [
      "I'm done talking today. Come back tomorrow.",
      "Enough haggling for one day. Tomorrow.",
      "My ears are tired. Try me tomorrow.",
      "No more today. The axe needs rest, and so do I.",
      "Come back tomorrow with a better offer.",
      "Stall's closed to you till tomorrow.",
    ],
    broke: [
      "My purse is empty. I'm not buying today.",
      "Can't pay you. Not a coin to spare.",
      "Sold nothing today, so I'm buying nothing.",
      "Purse is lighter than a twig. No deal.",
      "I'd buy, but I've got no coin left.",
      "Come back when folks have paid me.",
    ],
    wrapUp: [
      "We've gone round enough. That last price stands.",
      "I've said my number. Take it or walk.",
      "No more back and forth. Last price is on the table.",
      "We're going in circles. Same price as before.",
      "My throat's dry. Same offer, yes or no?",
      "That's my final word. Up to you.",
    ],
  },
  fishmonger: {
    name: "Fishmonger",
    style: "cheerful, chatty, loves gossip about the harbour and the gulls",
    examples: [
      "Ooh, cheeky! The gulls tried that price this morning too. Eighty-five and it's yours, love.",
      "Boats came in heavy today, I'm drowning in mackerel! Seventy each, quick before they start smelling.",
      "Nets came back empty, darling. Ninety-six, and that's me being generous.",
    ],
    hello: [
      "Fish so fresh they're still waving! What'll it be?",
      "Morning, love! Boats just came in.",
      "Ooh, a customer! Have a look, darling.",
      "Don't mind the gulls, they're just jealous. What are you after?",
      "Fresh from the lake and the sea! Tell me what you want.",
      "Hello, hello! Buying or selling today?",
      "The harbour's busy and so am I. Go on, ask!",
    ],
    accept: [
      "Lovely! It's a deal, friend!",
      "Oh go on then, deal!",
      "Sold! Don't let the gulls see it.",
      "You drive a sweet bargain. Done!",
      "Deal, darling. Pleasure as always.",
      "Wonderful, it's yours!",
    ],
    counter: [
      (p) => `How about ${p} C each? Can't go lower, the gulls are watching!`,
      (p) => `${p} C a fish, love. That's practically a gift.`,
      (p) => `I'll do ${p} C each, just for you.`,
      (p) => `${p} C apiece and I'll throw in a smile.`,
      (p) => `Let's say ${p} C each and call it friends.`,
      (p) => `${p} C each, darling. My husband would faint at that.`,
    ],
    annoyed: [
      "Oh my, that price smells worse than old bait!",
      "Cheeky! Even the gulls offer more.",
      "Darling, I have bills to pay!",
      "Ha! Nice try, love.",
      "That price would sink my little boat.",
      "You're making the fish blush with that one.",
    ],
    refuse: [
      "Sorry, love, I'm all haggled out. Tomorrow!",
      "My voice is gone for today, darling. Tomorrow!",
      "No more today, the gulls need me. Come back tomorrow!",
      "I'm done chatting for today, sweetheart.",
      "Tomorrow, love. I've talked myself dry.",
      "Come back tomorrow, I'll be in a better mood!",
    ],
    broke: [
      "Not a coin left in my bucket, I can't buy today!",
      "My purse is empty as a torn net, love.",
      "I'd love to buy, but I'm skint today.",
      "No coin, no catch. Sorry, darling.",
      "The gulls took my last coin, I swear.",
      "Can't buy today, I'm flat broke!",
    ],
    wrapUp: [
      "We've chatted long enough, love. That last price is the one.",
      "Darling, I can't go round again. Last offer stands.",
      "My last price is still there if you want it.",
      "No more haggling, sweetheart. Yes or no?",
      "I've said my bit, love. Same price.",
      "Same offer as before, take it before it swims off!",
    ],
  },
  smith: {
    name: "Smith",
    style: "proud, terse, respects good iron and players who don't waste his time",
    examples: ["Ten? This is iron, not pebbles. One fifty.", "Forge is cold, ore is scarce. Four hundred. Final.", "You sell good ore. One thirty each. Fair."],
    hello: [
      "Iron. Good iron. Speak.",
      "You want metal. Say what.",
      "Forge is hot. Be quick.",
      "Ore or coin. Which?",
      "Talk. I'm listening.",
      "Good steel needs a good price. Go.",
    ],
    accept: ["Agreed.", "Done.", "Fair. Deal.", "Accepted.", "Good. It's yours.", "That works."],
    counter: [
      (p) => `${p} C each.`,
      (p) => `${p} C apiece. Final.`,
      (p) => `${p} C each. Not less.`,
      (p) => `I'll take ${p} C each.`,
      (p) => `${p} C. That's fair iron.`,
      (p) => `${p} C a piece. Decide.`,
    ],
    annoyed: ["No.", "Insulting.", "That's scrap money.", "Don't waste my fire.", "Try again. Seriously.", "You jest."],
    refuse: ["Enough. Tomorrow.", "Forge is closed to you. Tomorrow.", "Done talking. Tomorrow.", "Come back tomorrow.", "No more today.", "Tomorrow. Not now."],
    broke: ["Purse is empty. Not buying.", "No coin. No deal.", "Can't buy. Empty purse.", "Nothing to pay with today.", "I'm out of coin.", "Not buying. Broke."],
    wrapUp: [
      "Last price stands.",
      "Said my price. Decide.",
      "No more rounds. Same number.",
      "Take it or leave it.",
      "We're done haggling. Same price.",
      "Final. Yes or no?",
    ],
  },
};

/** A random line from `bank` that does not appear in any of the last 3 `recent` replies (replies can join two
 *  lines, so this matches by substring); if every line is that recent, any line. */
export function pickLine(bank: string[], recent: string[], rand: () => number = Math.random): string {
  const last = recent.slice(-3);
  const fresh = bank.filter((l) => !last.some((r) => r.includes(l)));
  const pool = fresh.length > 0 ? fresh : bank;
  return pool[Math.min(Math.floor(rand() * pool.length), pool.length - 1)];
}

function pickCounter(p: Persona, price: number, recent: string[]): string {
  return pickLine(
    p.counter.map((f) => f(price)),
    recent,
  );
}

export type FallbackCtx = {
  merchant: string;
  room: [number, number];
  current: number;
  offerUnit?: number;
  lowball: boolean;
};

/** Deterministic pricing merchant: accepts in-room offers, otherwise meets halfway inside the room.
 *  Only the wording is random, and it skips the lines this merchant said to the player most recently. */
export function fallbackReply(c: FallbackCtx, recent: string[] = []) {
  const p = PERSONAS[c.merchant];
  const clamp = (x: number) => Math.min(Math.max(Math.round(x), c.room[0]), c.room[1]);
  if (c.offerUnit === undefined) {
    return { line: `${pickLine(p.hello, recent)} ${pickCounter(p, c.current, recent)}`, mood: "neutral", unitPrice: c.current, accept: false };
  }
  if (c.offerUnit >= c.room[0] && c.offerUnit <= c.room[1]) {
    return { line: pickLine(p.accept, recent), mood: "pleased", unitPrice: c.offerUnit, accept: true };
  }
  const price = clamp((c.offerUnit + c.current) / 2);
  const counter = pickCounter(p, price, recent);
  return {
    line: c.lowball ? `${pickLine(p.annoyed, recent)} ${counter}` : counter,
    mood: c.lowball ? "annoyed" : "neutral",
    unitPrice: price,
    accept: false,
  };
}
