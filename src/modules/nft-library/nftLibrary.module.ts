import { HttpModule } from '@nestjs/axios';
import { Module } from '@nestjs/common';
import { NftLibraryController } from './token.controller';
import { NftLibraryService } from './token.service';

@Module({
  imports: [HttpModule],
  providers: [NftLibraryService],
  controllers: [NftLibraryController],
  exports: [NftLibraryService],
})
export class NftLibraryModule {}