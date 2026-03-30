import { Module } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import { AppController } from './app.controller';
import { AppService } from './app.service';
import { AuthModule } from './auth/auth.module';
import { DeparturesModule } from './departures/departures.module';
import { PrismaModule } from './prisma/prisma.module';
import { RoutesModule } from './routes/routes.module';
import { TransitModule } from './transit/transit.module';

@Module({
  imports: [
    ConfigModule.forRoot({ isGlobal: true }),
    PrismaModule,
    AuthModule,
    RoutesModule,
    TransitModule,
    DeparturesModule,
  ],
  controllers: [AppController],
  providers: [AppService],
})
export class AppModule {}
