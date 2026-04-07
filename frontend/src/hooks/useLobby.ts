import { useQuery } from "@tanstack/react-query";
import { suiClient } from "../suiClient";
import { LOBBY_ID } from "../config";

export interface OpenGame {
  gameId: string;
  creator: string;
  betAmount: string;
}

export interface ActiveGame {
  gameId: string;
  white: string;
  black: string;
}

interface LobbyData {
  openGames: OpenGame[];
  activeGames: ActiveGame[];
}

export function useLobby() {
  const { data, isLoading, error, refetch } = useQuery<LobbyData>({
    queryKey: ["lobby", LOBBY_ID],
    queryFn: async () => {
      const response = await suiClient.getObject({
        objectId: LOBBY_ID,
        include: { json: true }
      });
      const json = response.object.json;
      if (!json) return { openGames: [], activeGames: [] };
      return parseLobby(json);
    },
    refetchInterval: 3000
  });

  return {
    openGames: data?.openGames ?? [],
    activeGames: data?.activeGames ?? [],
    isLoading,
    error,
    refetch
  };
}

function parseLobby(json: Record<string, unknown>): LobbyData {
  const openGames = parseOpenGames(json.open_games as unknown[]);
  const activeGames = parseActiveGames(json.active_games as unknown[]);
  return { openGames, activeGames };
}

function parseOpenGames(arr: unknown[]): OpenGame[] {
  if (!Array.isArray(arr)) return [];
  return arr.map((entry) => {
    const obj = entry as Record<string, unknown>;
    return {
      gameId: String(obj.game_id),
      creator: String(obj.creator),
      betAmount: String(obj.bet_amount)
    };
  });
}

function parseActiveGames(arr: unknown[]): ActiveGame[] {
  if (!Array.isArray(arr)) return [];
  return arr.map((entry) => {
    const obj = entry as Record<string, unknown>;
    return {
      gameId: String(obj.game_id),
      white: String(obj.white),
      black: String(obj.black)
    };
  });
}
