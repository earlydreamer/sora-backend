import { IsBoolean, IsInt, IsOptional, IsString, Matches, Max, Min } from 'class-validator';

export class CreateRouteDto {
  @IsString()
  name: string;

  @IsString()
  origin: string;

  @IsString()
  destination: string;

  @IsString()
  @Matches(/^\d{2}:\d{2}$/, { message: 'targetArrivalTime must be HH:MM format' })
  targetArrivalTime: string;

  @IsOptional()
  @IsInt()
  @Min(0)
  @Max(120)
  bufferMinutes?: number;

  @IsOptional()
  @IsBoolean()
  isDefault?: boolean;
}
