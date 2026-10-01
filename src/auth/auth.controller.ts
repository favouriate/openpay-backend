import { Body, Controller, HttpCode, HttpStatus, Post } from '@nestjs/common';
import { AuthService } from './auth.service.js';
import { registerSchema } from './schemas/register.schema.js';
import type { RegisterInput } from './schemas/register.schema.js';
import type { RegisterResponse } from './types/register-response.type.js';

@Controller('auth')
export class AuthController {
  constructor(private readonly authService: AuthService) {}

  @Post('register')
  @HttpCode(HttpStatus.CREATED)
  register(
    @Body({ schema: registerSchema }) input: RegisterInput,
  ): Promise<RegisterResponse> {
    return this.authService.register(input);
  }
}
