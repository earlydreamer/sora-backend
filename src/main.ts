import { ValidationPipe } from '@nestjs/common';
import { NestFactory } from '@nestjs/core';
import { AppModule } from './app.module';

async function bootstrap() {
  const app = await NestFactory.create(AppModule);
  app.useGlobalPipes(
    new ValidationPipe({ whitelist: true, forbidNonWhitelisted: true }),
  );
  // TODO: 프로덕션 배포 시 origin을 Cloudflare Pages 도메인으로 제한할 것
  // 예: app.enableCors({ origin: process.env.ALLOWED_ORIGIN })
  app.enableCors();
  await app.listen(process.env.PORT ?? 3000);
}
void bootstrap();
