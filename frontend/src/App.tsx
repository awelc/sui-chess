import { ConnectButton, useCurrentAccount } from "@mysten/dapp-kit";
import { NETWORK } from "./config";
import "./App.css";

function App() {
  const account = useCurrentAccount();

  return (
    <div className="app">
      <header>
        <h1>Sui Chess</h1>
        <ConnectButton />
      </header>

      <main>
        {account ? (
          <div className="connected">
            <p>
              Connected to <strong>{NETWORK}</strong> as
            </p>
            <code className="address">{account.address}</code>
            <p className="hint">Game setup coming next...</p>
          </div>
        ) : (
          <div className="welcome">
            <p>Connect your wallet to play chess on Sui.</p>
          </div>
        )}
      </main>
    </div>
  );
}

export default App;
