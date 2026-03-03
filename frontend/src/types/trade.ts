export enum TradeStatus {
  Created = 0,
  BothDeposited = 1,
  Settled = 2,
  Refunded = 3,
  Expired = 4,
}

export interface TradeParams {
  asset: string;
  amount: string;
  wantAsset: string;
  wantAmount: string;
  destinationChain: number;
}

export interface Trade {
  tradeId: `0x${string}`;
  partyA: `0x${string}`;
  partyB: `0x${string}`;
  status: TradeStatus;
  createdAt: bigint;
}
