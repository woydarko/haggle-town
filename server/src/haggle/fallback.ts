export type Persona = {
  name: string;
  style: string;
  hello: string;
  accept: string;
  counter: (price: number) => string;
  annoyed: string;
  refuse: string;
  broke: string;
};

export const PERSONAS: Record<string, Persona> = {
  woodcutter: {
    name: "Woodcutter",
    style: "gruff, practical, few words, proud of honest work",
    hello: "Fresh-cut wood. Make me an offer.",
    accept: "Fine. Deal.",
    counter: (p) => `${p} C each. Take it or leave it.`,
    annoyed: "That's an insult to my axe.",
    refuse: "I'm done talking today. Come back tomorrow.",
    broke: "My purse is empty. I'm not buying today.",
  },
  fishmonger: {
    name: "Fishmonger",
    style: "cheerful, chatty, loves gossip about the sea",
    hello: "Fish so fresh they're still waving! What'll it be?",
    accept: "Lovely! It's a deal, friend!",
    counter: (p) => `How about ${p} C each? Can't go lower, the gulls are watching!`,
    annoyed: "Oh my, that price smells worse than old bait!",
    refuse: "Sorry, love, I'm all haggled out. Tomorrow!",
    broke: "Not a coin left in my bucket, I can't buy today!",
  },
  smith: {
    name: "Smith",
    style: "proud, terse, respects good iron",
    hello: "Iron. Good iron. Speak.",
    accept: "Agreed.",
    counter: (p) => `${p} C each.`,
    annoyed: "No.",
    refuse: "Enough. Tomorrow.",
    broke: "Purse is empty. Not buying.",
  },
};

export type FallbackCtx = {
  merchant: string;
  room: [number, number];
  current: number;
  offerUnit?: number;
  lowball: boolean;
};

/** Deterministic merchant: accepts in-room offers, otherwise meets halfway inside the room. */
export function fallbackReply(c: FallbackCtx) {
  const p = PERSONAS[c.merchant];
  const clamp = (x: number) => Math.min(Math.max(Math.round(x), c.room[0]), c.room[1]);
  if (c.offerUnit === undefined) {
    return { line: `${p.hello} ${p.counter(c.current)}`, mood: "neutral", unitPrice: c.current, accept: false };
  }
  if (c.offerUnit >= c.room[0] && c.offerUnit <= c.room[1]) {
    return { line: p.accept, mood: "pleased", unitPrice: c.offerUnit, accept: true };
  }
  const price = clamp((c.offerUnit + c.current) / 2);
  return {
    line: c.lowball ? `${p.annoyed} ${p.counter(price)}` : p.counter(price),
    mood: c.lowball ? "annoyed" : "neutral",
    unitPrice: price,
    accept: false,
  };
}
