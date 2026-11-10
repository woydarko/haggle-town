export type Queue = <T>(job: () => Promise<T>) => Promise<T>;

/** Strict FIFO, one job at a time: one signer key = one nonce stream. */
export function createQueue(): Queue {
  let tail: Promise<unknown> = Promise.resolve();
  return <T>(job: () => Promise<T>) => {
    const run = tail.then(job, job);
    tail = run.catch(() => undefined);
    return run;
  };
}
