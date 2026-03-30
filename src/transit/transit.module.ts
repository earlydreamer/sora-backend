import { Module } from '@nestjs/common';
import { RoutesModule } from '../routes/routes.module';
import { TransitController } from './transit.controller';
import { TransitService } from './transit.service';

@Module({
  imports: [RoutesModule],
  controllers: [TransitController],
  providers: [TransitService],
})
export class TransitModule {}
