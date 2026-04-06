import { useState, useRef, useEffect } from "react";
import {
  ConnectModal,
  useCurrentAccount,
  useDisconnectWallet,
} from "@mysten/dapp-kit";
import GameSetup from "./components/GameSetup";
import ChessGame from "./components/ChessGame";
import "./App.css";

function truncateAddress(addr: string) {
  return `${addr.slice(0, 6)}...${addr.slice(-4)}`;
}

function WalletButton() {
  const account = useCurrentAccount();
  const { mutate: disconnect } = useDisconnectWallet();
  const [open, setOpen] = useState(false);
  const [copied, setCopied] = useState(false);
  const menuRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    if (!open) return;
    const handleClick = (e: MouseEvent) => {
      if (menuRef.current && !menuRef.current.contains(e.target as Node)) {
        setOpen(false);
      }
    };
    document.addEventListener("mousedown", handleClick);
    return () => document.removeEventListener("mousedown", handleClick);
  }, [open]);

  if (!account) {
    return (
      <ConnectModal
        trigger={<button className="wallet-btn">Connect Wallet</button>}
      />
    );
  }

  const copyAddress = () => {
    navigator.clipboard.writeText(account.address);
    setCopied(true);
    setTimeout(() => setCopied(false), 1500);
  };

  return (
    <div className="wallet-menu" ref={menuRef}>
      <button className="wallet-btn" onClick={() => setOpen(!open)}>
        {truncateAddress(account.address)}
      </button>
      {open && (
        <div className="wallet-dropdown">
          <button
            className="wallet-dropdown-item"
            onClick={() => {
              copyAddress();
              setOpen(false);
            }}
          >
            {copied ? "Copied!" : truncateAddress(account.address)}
          </button>
          <button
            className="wallet-dropdown-item"
            onClick={() => {
              disconnect();
              setOpen(false);
            }}
          >
            Disconnect
          </button>
        </div>
      )}
    </div>
  );
}

function App() {
  const account = useCurrentAccount();
  const [gameId, setGameId] = useState<string | null>(null);

  return (
    <div className="app">
      <header>
        <h1>Sui Chess</h1>
        <WalletButton />
      </header>

      <main>
        {!account ? (
          <div className="welcome">
            <p>Connect your wallet to play chess on Sui.</p>
          </div>
        ) : gameId ? (
          <ChessGame gameId={gameId} onLeave={() => setGameId(null)} />
        ) : (
          <GameSetup onGameReady={setGameId} />
        )}
      </main>
    </div>
  );
}

export default App;
