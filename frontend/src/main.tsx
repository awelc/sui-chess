import { StrictMode } from "react";
import { createRoot } from "react-dom/client";
import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import { SuiClientProvider, WalletProvider } from "@mysten/dapp-kit";
import { getJsonRpcFullnodeUrl } from "@mysten/sui/jsonRpc";
import { NETWORK } from "./config";
import App from "./App";
import "@mysten/dapp-kit/dist/index.css";
import "./index.css";

const queryClient = new QueryClient();

const networks = {
  devnet: { url: getJsonRpcFullnodeUrl("devnet") },
  testnet: { url: getJsonRpcFullnodeUrl("testnet") },
  mainnet: { url: getJsonRpcFullnodeUrl("mainnet") }
};

createRoot(document.getElementById("root")!).render(
  <StrictMode>
    <QueryClientProvider client={queryClient}>
      <SuiClientProvider networks={networks} defaultNetwork={NETWORK}>
        <WalletProvider autoConnect>
          <App />
        </WalletProvider>
      </SuiClientProvider>
    </QueryClientProvider>
  </StrictMode>
);
