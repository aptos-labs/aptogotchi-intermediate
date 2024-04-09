"use client";

import { Dispatch, SetStateAction, useEffect, useState } from "react";
import { Pet } from "../Pet";
import { Food } from "../Food";
import { Details } from "../Pet/Details";
import { Summary } from "../Pet/Summary";
import { Action, Actions } from "../Pet/Actions";
import { APTOGOTCHI_CONTRACT_ADDRESS } from "@/utils/const";
import { MoveValue } from "@aptos-labs/ts-sdk";
import { useWallet } from "@aptos-labs/wallet-adapter-react";
import { getAptosClient } from "@/utils/aptosClient";

interface AptogotchiProps {
  pet: Pet;
  food: Food;
  setPet: Dispatch<SetStateAction<Pet | undefined>>;
  setFood: Dispatch<SetStateAction<Food | undefined>>;
}

const aptosClient = getAptosClient();

export function Aptogotchi({ food, pet, setFood, setPet }: AptogotchiProps) {
  const { account, network, signAndSubmitTransaction } = useWallet();
  const [selectedAction, setSelectedAction] = useState<Action>("play");
  const [hasBattleExt, setHasBattleExt] = useState(false);

  useEffect(() => {
    aptosClient
      .view({
        payload: {
          function: `${APTOGOTCHI_CONTRACT_ADDRESS}::main::has_battle_ext`,
          functionArguments: [account?.address],
        },
      })
      .then((response: MoveValue[]) => {
        setHasBattleExt(response[0] as boolean);
      });
  }, [pet]);

  return (
    <div className="flex flex-row self-center gap-12 m-8">
      <div className="flex flex-col gap-4 w-[360px]">
        <Pet pet={pet} setPet={setPet} />
        <Details
          food={food}
          pet={pet}
          setFood={setFood}
          setPet={setPet}
          hasBattleExt={hasBattleExt}
        />
      </div>
      <div className="flex flex-col gap-8 w-[680px] h-full">
        <Actions
          selectedAction={selectedAction}
          setSelectedAction={setSelectedAction}
          setFood={setFood}
          setPet={setPet}
          setHasBattleExt={setHasBattleExt}
          pet={pet}
          food={food}
          hasBattleExt={hasBattleExt}
        />
        <Summary pet={pet} />
      </div>
    </div>
  );
}
