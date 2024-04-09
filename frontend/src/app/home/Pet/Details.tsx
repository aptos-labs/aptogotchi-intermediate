"use client";

import { FaCopy } from "react-icons/fa";
import { HealthBar } from "@/components/HealthBar";
import { Pet } from ".";
import { Dispatch, SetStateAction, useEffect, useState } from "react";
import { useWallet } from "@aptos-labs/wallet-adapter-react";
import { Food } from "../Food";
import { getAptosClient } from "@/utils/aptosClient";
import { APTOGOTCHI_CONTRACT_ADDRESS } from "@/utils/const";
import { MoveValue } from "@aptos-labs/ts-sdk";

export interface DetailsProps {
  pet: Pet;
  food: Food;
  hasBattleExt: boolean;
  setPet: Dispatch<SetStateAction<Pet | undefined>>;
  setFood?: Dispatch<SetStateAction<Food | undefined>>;
}

const aptosClient = getAptosClient();

export function Details({ pet, food, hasBattleExt, setPet, setFood }: DetailsProps) {
  const [newName, setNewName] = useState(pet.name);
  const { account } = useWallet();
  const owner = account?.ansName ? `${account?.ansName}.apt` : account?.address || "";
  const [battleExt, setBattleExt] = useState<[number, number]>();

  useEffect(() => {
    if (!account?.address) return;
    aptosClient
      .view({
        payload: {
          function: `${APTOGOTCHI_CONTRACT_ADDRESS}::main::get_battle_ext`,
          functionArguments: [account?.address],
        },
      })
      .then((response: MoveValue[]) => {
        setBattleExt(response as [number, number]);
      });
  }, [pet, hasBattleExt]);

  const handleCopyOwnerAddrOrName = () => {
    navigator.clipboard.writeText(owner);
  };

  const nameFieldComponent = (
    <div className="nes-field">
      <label htmlFor="name_field">Name</label>
      <div className="relative">
        <input type="text" id="owner_field" className="nes-input pr-12" disabled value={newName} />
        <button
          className="absolute right-4 top-1/2 -translate-y-1/2 nes-pointer disabled:cursor-not-allowed text-gray-400 disabled:text-gray-400"
          onClick={handleCopyOwnerAddrOrName}
        >
          <FaCopy className="h-8 w-8 drop-shadow-sm" />
        </button>
      </div>
    </div>
  );

  const ownerFieldComponent = (
    <div className="nes-field">
      <label htmlFor="owner_field">Owner</label>
      <div className="relative">
        <input type="text" id="owner_field" className="nes-input pr-12" disabled value={owner} />
        <button
          className="absolute right-4 top-1/2 -translate-y-1/2 nes-pointer disabled:cursor-not-allowed text-gray-400 disabled:text-gray-400"
          onClick={handleCopyOwnerAddrOrName}
        >
          <FaCopy className="h-8 w-8 drop-shadow-sm" />
        </button>
      </div>
    </div>
  );

  return (
    <div className="flex flex-col gap-4">
      <div className="flex flex-col">
        <label>Energy Points</label>
        <HealthBar totalHealth={10} currentHealth={pet.energy_points} icon="star" />
      </div>
      <div className="flex flex-col">
        <label>Food</label>
        <Food food={food} setFood={setFood} />
      </div>
      {hasBattleExt ? (
        battleExt && (
          <div className="flex flex-col">
            <div className="nes-container with-title is-centered">
              <p className="title">Battle Extension</p>
              <div className="justify-between">
                <p>Attack Points: {battleExt[0]}</p>
                <p>Defense Points: {battleExt[1]}</p>
              </div>
            </div>
          </div>
        )
      ) : (
        <div className="nes-container with-title is-centered">
          <p className="title">Battle Extension</p>
          <p>No Battle Extension</p>
        </div>
      )}
      <div className="flex flex-col gap-2">
        {nameFieldComponent}
        {ownerFieldComponent}
        <br />
      </div>
    </div>
  );
}
