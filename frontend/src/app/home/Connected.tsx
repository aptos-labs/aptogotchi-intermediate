"use client";

import { useState, useEffect, useCallback } from "react";
import { Aptogotchi } from "./Aptogotchi";
import { useWallet } from "@aptos-labs/wallet-adapter-react";
import { Mint } from "./Mint";
import { Pet } from "./Pet";
import { Food } from "./Food";
import { Modal } from "@/components/Modal";
import { getAptosClient } from "@/utils/aptosClient";
import { APTOGOTCHI_CONTRACT_ADDRESS } from "@/utils/const";
import { MoveValue } from "@aptos-labs/ts-sdk";

const TESTNET_ID = "2";

const aptosClient = getAptosClient();

export function Connected() {
  const [hasPet, SetHasPet] = useState(false);
  const [pet, setPet] = useState<Pet>();
  const [food, setFood] = useState<Food>();
  const { account, network } = useWallet();

  const fetchPet = useCallback(async () => {
    if (!account?.address) return;
    if (!hasPet) return;

    const response = await aptosClient.view({
      payload: {
        function: `${APTOGOTCHI_CONTRACT_ADDRESS}::main::get_aptogotchi`,
        functionArguments: [account.address],
      },
    });
    const noPet = ["", "0", "0", "0x"];

    if (JSON.stringify(response) !== JSON.stringify(noPet)) {
      setPet({
        name: response[0] as unknown as string,
        energy_points: parseInt(response[2] as unknown as string),
        parts: (response[3] as unknown as string).split("0").slice(2).map(Number),
        accessories: response[4] as unknown as string,
      });
    }
  }, [account?.address, hasPet]);

  const fetchFood = useCallback(async () => {
    if (!account?.address) return;
    if (!hasPet) return;

    const response = await aptosClient.view({
      payload: {
        function: `${APTOGOTCHI_CONTRACT_ADDRESS}::food::get_food_balance`,
        functionArguments: [account.address],
      },
    });
    const noFood = ["", "0", "0", "0x"];

    if (JSON.stringify(response) !== JSON.stringify(noFood)) {
      setFood({
        number: parseInt(response[0] as unknown as string),
      });
    }
  }, [account?.address, hasPet]);

  useEffect(() => {
    if (!account?.address) return;

    aptosClient
      .view({
        payload: {
          function: `${APTOGOTCHI_CONTRACT_ADDRESS}::main::has_aptogotchi`,
          functionArguments: [account.address],
        },
      })
      .then((response: MoveValue[]) => {
        SetHasPet(response[0] as boolean);
      });
  }, [account?.address, network]);

  useEffect(() => {
    if (!account?.address || !network || !hasPet) return;

    fetchPet();
    fetchFood();
  }, [account?.address, fetchPet, fetchFood, hasPet, network]);

  return (
    <div className="flex flex-col gap-3 p-3">
      {network?.chainId !== TESTNET_ID && <Modal />}
      {pet && food ? (
        <Aptogotchi food={food} pet={pet} setPet={setPet} setFood={setFood} />
      ) : (
        <Mint fetchPet={fetchPet} />
      )}
    </div>
  );
}
