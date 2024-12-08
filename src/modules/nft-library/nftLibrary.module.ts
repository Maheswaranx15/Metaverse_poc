import { HttpModule } from '@nestjs/axios';
import { Module } from '@nestjs/common';
import { NftLibraryController } from './nftLibrary.controller';
import { NftLibraryService } from './nftLibrary.service';

@Module({
  imports: [HttpModule],
  providers: [NftLibraryService],
  controllers: [NftLibraryController],
  exports: [NftLibraryService],
})
export class NftLibraryModule {}