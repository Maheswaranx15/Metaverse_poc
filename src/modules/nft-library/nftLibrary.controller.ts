import { Body, Controller, Get, NotFoundException, Param, Post } from '@nestjs/common';
import { ApiBadRequestResponse, ApiOkResponse, ApiOperation, ApiTags } from '@nestjs/swagger';
import {
  MintRequestDTO,
  MintResponseDTO,
  balanceResponseDTO,
} from './nftLibrary.dto';
import { NftLibraryService } from './nftLibrary.service';

@ApiTags('nftLibrary')
@Controller('/tokens')
export class NftLibraryController {
  constructor(private readonly nftLibraryService: NftLibraryService) {}
  @Get('/balance/:address')
  @ApiOperation({ summary: 'Get balance of an address' })
  @ApiOkResponse({
    description: 'Returns the balance of an address',
  })
  async balanceOf(@Param('address') address: string): Promise<balanceResponseDTO> {
    try {
      console.log(address);

      return await this.nftLibraryService.balanceOf(address);
    } catch (error) {
      console.error(error);
      throw new NotFoundException('Error retrieving balance');
    }
  }

  @Post('/mint')
  @ApiOperation({ summary: 'Mint ERC721 NFT' })
  @ApiOkResponse({
    description: 'Returns a success message with transaction hash and token ID',
    type: MintResponseDTO,
    isArray: false,
  })
  @ApiBadRequestResponse({ description: 'Invalid input parameters' })
  async mintNft(@Body() body: MintRequestDTO): Promise<MintResponseDTO> {
    try {
      const { to, amount } = body;
      console.log(body);
      // Validate input parameters
      if (!to || typeof to !== 'string' || !amount || typeof amount !== 'number') {
        throw new Error('Invalid input parameters');
      }
      return await this.nftLibraryService.mintNft(to, amount);
    } catch (error) {
      console.error(error);
      throw error; // Throw the original error object instead of creating a new one
    }
  }
}