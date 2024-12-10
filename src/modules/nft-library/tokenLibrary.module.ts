import { HttpModule } from '@nestjs/axios';
import { Module } from '@nestjs/common';
import { NftLibraryController } from './tokenlibrary.controller';
import { NftLibraryService } from './tokenLibrary.service';

@Module({
  imports: [HttpModule],
  providers: [NftLibraryService],
  controllers: [NftLibraryController],
  exports: [NftLibraryService],
})
export class NftLibraryModule {}