import { useQuery } from "@tanstack/react-query";
import { suiClient } from "../suiClient";
import { parseGameObject, type GameState } from "../lib/boardParser";

export function useGame(gameId: string) {
  const { data, isLoading, error, refetch } = useQuery<GameState>({
    queryKey: ["game", gameId],
    queryFn: async () => {
      const response = await suiClient.getObject({
        objectId: gameId,
        include: { json: true }
      });
      const json = response.object.json;
      if (!json) throw new Error("Game object has no JSON content");
      return parseGameObject(json);
    },
    refetchInterval: 3000
  });

  return { game: data ?? null, isLoading, error, refetch };
}
