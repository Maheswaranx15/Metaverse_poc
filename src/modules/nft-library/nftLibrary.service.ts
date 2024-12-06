import { HttpService } from '@nestjs/axios';
import { Injectable } from '@nestjs/common';
import { ethers } from 'ethers';
import { erc20 } from './abi/erc20';
import {
  MintResponseDTO,
  balanceResponseDTO,
} from './nftLibrary.dto';

@Injectable()
export class NftLibraryService {
  constructor(private readonly httpService: HttpService) {}

  async getGasPrice(): Promise<{ maxFeePerGas: number; maxPriorityFeePerGas: number }> {
    const { data } = await this.httpService.axiosRef.get(process.env.GAS_STATION_URL);
    const maxFeePerGas = Math.ceil(data.standard.maxFee) * 10 ** 9;
    const maxPriorityFeePerGas = Math.ceil(data.standard.maxPriorityFee) * 10 ** 9;
    return { maxFeePerGas, maxPriorityFeePerGas };
  }
  async mintNft(to: string, amount: number): Promise<MintResponseDTO> {
    const provider = new ethers.JsonRpcProvider(process.env.RPC_PROVIDER);
    const signer = new ethers.Wallet(process.env.MINTER_KEY, provider);
    const contract = new ethers.Contract(erc20.address, erc20.abi, signer);
    const { maxFeePerGas, maxPriorityFeePerGas } = await this.getGasPrice();
    const tx = await contract.mint(to, amount, { maxFeePerGas, maxPriorityFeePerGas });
    const receipt = await tx.wait();
    console.log(receipt);

    // const tokenId = receipt.events[0].args[2];
    return {
      message: 'Token Transferred successfully',
      transactionHash: receipt.transactionHash,
      amount: amount.toString(),
    };
  }

  async balanceOf(owner: string): Promise<balanceResponseDTO> {
    const provider = new ethers.JsonRpcProvider(process.env.RPC_PROVIDER);
    const signer = new ethers.Wallet(process.env.MINTER_KEY, provider);
    const contract = new ethers.Contract(erc20.address, erc20.abi, signer);
    const balance = await contract.balanceOf(owner);
    return {
      balance: balance.toString(),
    };
  }

 
}