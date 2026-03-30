import { IsDateString, IsString } from 'class-validator';

export class CreateDepartureDto {
  @IsString()
  routeId: string;

  @IsDateString()
  predictedArrivalAt: string;

  @IsDateString()
  departedAt: string;
}
