import { IsArray, IsNumber, IsOptional, IsString } from 'class-validator';

export class MintRequestDTO {
  @IsString()
  to: string;

  @IsNumber()
  amount: number;
}

export class MintResponseDTO {
  @IsString()
  message: string;

  @IsString()
  transactionHash: string;

  @IsString()
  amount: string;
}

export class balanceResponseDTO {
  @IsString()
  balance: string;
}


