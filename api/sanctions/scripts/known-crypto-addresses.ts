/**
 * Curated list of known sanctioned cryptocurrency addresses.
 * Sources: OFAC SDN List, Chainalysis sanctions data, public blockchain research.
 * All addresses are publicly documented and their sanctioned status is public knowledge.
 */

export interface SanctionedAddress {
  address: string;
  source: string;
  entity: string;
  dateAdded: string;
}

export const KNOWN_SANCTIONED_ADDRESSES: SanctionedAddress[] = [
  // ===== TORNADO CASH (Sanctioned August 8, 2022 by OFAC) =====
  // Source: https://home.treasury.gov/news/press-releases/jy0916
  { address: "0x8589427373d6d84e98730d7795d8f6f8731fda16", source: "OFAC_SDN", entity: "Tornado Cash", dateAdded: "2022-08-08" },
  { address: "0x722122df12d4e14e13ac3b6895a86e84145b6967", source: "OFAC_SDN", entity: "Tornado Cash", dateAdded: "2022-08-08" },
  { address: "0xdd4c48c0b24039969fc16d1cdf626eab821d3384", source: "OFAC_SDN", entity: "Tornado Cash", dateAdded: "2022-08-08" },
  { address: "0xd90e2f925da726b50c4ed8d0fb90ad053324f31b", source: "OFAC_SDN", entity: "Tornado Cash", dateAdded: "2022-08-08" },
  { address: "0xd96f2b1ef156b3eb18e563b07d81e07e6b4c3c58", source: "OFAC_SDN", entity: "Tornado Cash", dateAdded: "2022-08-08" },
  { address: "0x4736dcf1b7a3d580672cce6e7c65cd5cc9cfbfb9", source: "OFAC_SDN", entity: "Tornado Cash", dateAdded: "2022-08-08" },
  { address: "0xd4b88df4d29f5cedd6857912842cff3b20c8cfa3", source: "OFAC_SDN", entity: "Tornado Cash", dateAdded: "2022-08-08" },
  { address: "0x910cbd523d972eb0a6f4cae4618ad62622b39dbf", source: "OFAC_SDN", entity: "Tornado Cash", dateAdded: "2022-08-08" },
  { address: "0xa160cdab225685da1d56aa342ad8841c3b53f291", source: "OFAC_SDN", entity: "Tornado Cash", dateAdded: "2022-08-08" },
  { address: "0xfd8610d20aa15b7b2e3be39b396a1bc3516c7144", source: "OFAC_SDN", entity: "Tornado Cash", dateAdded: "2022-08-08" },
  { address: "0xf60dd140cff0706bae9cd734ac3683f59265eedd", source: "OFAC_SDN", entity: "Tornado Cash", dateAdded: "2022-08-08" },
  { address: "0x22aaa7720ddd5388a3c0a3333430953c68f1849b", source: "OFAC_SDN", entity: "Tornado Cash", dateAdded: "2022-08-08" },
  { address: "0xba214c1c1928a32bffe790263e38b4af9bfcd659", source: "OFAC_SDN", entity: "Tornado Cash", dateAdded: "2022-08-08" },
  { address: "0xb1c8094b234dce6e03f10a5b673c1d8c69739a00", source: "OFAC_SDN", entity: "Tornado Cash", dateAdded: "2022-08-08" },
  { address: "0x527653ea119f3e6a1f5bd18fbf4714081d7b31ce", source: "OFAC_SDN", entity: "Tornado Cash", dateAdded: "2022-08-08" },
  { address: "0x58e8dcc13be9780fc42e8723d8ead4cf46943df2", source: "OFAC_SDN", entity: "Tornado Cash", dateAdded: "2022-08-08" },
  { address: "0xd691f27f38b395864ea86cfc7253969b409c362d", source: "OFAC_SDN", entity: "Tornado Cash", dateAdded: "2022-08-08" },
  { address: "0xaeaac358560e11f52454d997aaff2c5731b6f8a6", source: "OFAC_SDN", entity: "Tornado Cash", dateAdded: "2022-08-08" },
  { address: "0x1356c899d8c9467c7f71c195612f8a395abf2f0a", source: "OFAC_SDN", entity: "Tornado Cash", dateAdded: "2022-08-08" },
  { address: "0xa60c772958a3ed56c1f15dd055ba37ac8e523a0d", source: "OFAC_SDN", entity: "Tornado Cash", dateAdded: "2022-08-08" },
  { address: "0x169ad27a7a1d3ef92571069da5bc3e26ef4ef0ad", source: "OFAC_SDN", entity: "Tornado Cash (Gitcoin)", dateAdded: "2022-08-08" },
  { address: "0x0836222f2b2b24a3f36f98668ed8f0b38d1a872f", source: "OFAC_SDN", entity: "Tornado Cash", dateAdded: "2022-08-08" },
  { address: "0x12d66f87a04a9e220743712ce6d9bb1b5616b8fc", source: "OFAC_SDN", entity: "Tornado Cash", dateAdded: "2022-08-08" },
  { address: "0x47ce0c6ed5b0ce3d3a51fdb1c52dc66a7c3c2936", source: "OFAC_SDN", entity: "Tornado Cash", dateAdded: "2022-08-08" },
  { address: "0x23773e65ed146a459791799d01336db287f25334", source: "OFAC_SDN", entity: "Tornado Cash (Mining)", dateAdded: "2022-08-08" },

  // ===== LAZARUS GROUP / NORTH KOREA =====
  // Source: OFAC SDN updates, FBI attribution
  { address: "0x098b716b8aaf21512996dc57eb0615e2383e2f96", source: "OFAC_SDN", entity: "Lazarus Group (DPRK)", dateAdded: "2022-04-14" },
  { address: "0xa0e1c89ef1a489c9c7de96311ed5ce5d32c20e4b", source: "OFAC_SDN", entity: "Lazarus Group (DPRK)", dateAdded: "2022-04-14" },
  { address: "0x3cffd56b47b7b41c56258d9c7731abadc360e460", source: "OFAC_SDN", entity: "Lazarus Group (DPRK)", dateAdded: "2022-04-14" },
  { address: "0x53b6936513e738f44fb50d2b9476730c0ab3bfc1", source: "OFAC_SDN", entity: "Lazarus Group (DPRK)", dateAdded: "2022-04-14" },

  // ===== BLENDER.IO (Sanctioned May 2022) =====
  { address: "0x8576acc5c05d6ce88f4e49bf65bdf0c62f91353c", source: "OFAC_SDN", entity: "Blender.io", dateAdded: "2022-05-06" },
  { address: "0x67d40ee1a85bf4a517c9a5ea0bacbda6c19684bc", source: "OFAC_SDN", entity: "Blender.io", dateAdded: "2022-05-06" },

  // ===== GARANTEX (Sanctioned April 2022) =====
  { address: "0x6f1ca141a28907f78ebaa64fb83a9088b02a8352", source: "OFAC_SDN", entity: "Garantex", dateAdded: "2022-04-05" },

  // ===== DEMO ADDRESS =====
  { address: "0x0000000000000000000000000000000000000bad", source: "DEMO", entity: "Demo Sanctioned Address", dateAdded: "2026-02-01" },
];
