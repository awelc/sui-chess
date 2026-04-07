import { SuiGrpcClient } from "@mysten/sui/grpc";
import { NETWORK } from "./config";

const GRPC_URLS: Record<string, string> = {
  devnet: "https://fullnode.devnet.sui.io:443",
  testnet: "https://fullnode.testnet.sui.io:443",
  mainnet: "https://fullnode.mainnet.sui.io:443"
};

export const suiClient = new SuiGrpcClient({
  network: NETWORK,
  baseUrl: GRPC_URLS[NETWORK]
});
