import {
  ConflictException,
  Injectable,
  UnauthorizedException,
} from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import * as bcrypt from 'bcrypt';
import { PrismaService } from '../prisma/prisma.service';
import { LoginDto } from './dto/login.dto';
import { RegisterDto } from './dto/register.dto';

@Injectable()
export class AuthService {
  constructor(
    private prisma: PrismaService,
    private jwt: JwtService,
  ) {}

  async register(dto: RegisterDto) {
    const existing = await this.prisma.user.findUnique({
      where: { email: dto.email },
    });
    if (existing) throw new ConflictException('이미 사용 중인 이메일입니다.');

    const hashed = await bcrypt.hash(dto.password, 12);
    let user: { id: string; email: string };
    try {
      user = await this.prisma.user.create({
        data: { email: dto.email, password: hashed },
        select: { id: true, email: true },
      });
    } catch (err: unknown) {
      // P2002: 유니크 제약 위반 — findUnique 이후 동시 요청으로 중복 발생 시
      if (
        typeof err === 'object' &&
        err !== null &&
        (err as { code?: string }).code === 'P2002'
      ) {
        throw new ConflictException('이미 사용 중인 이메일입니다.');
      }
      throw err;
    }

    return { access_token: this.sign(user.id, user.email) };
  }

  async login(dto: LoginDto) {
    const user = await this.prisma.user.findUnique({
      where: { email: dto.email },
    });
    if (!user)
      throw new UnauthorizedException(
        '이메일 또는 비밀번호가 올바르지 않습니다.',
      );

    const valid = await bcrypt.compare(dto.password, user.password);
    if (!valid)
      throw new UnauthorizedException(
        '이메일 또는 비밀번호가 올바르지 않습니다.',
      );

    return { access_token: this.sign(user.id, user.email) };
  }

  private sign(userId: string, email: string) {
    return this.jwt.sign({ sub: userId, email });
  }
}
