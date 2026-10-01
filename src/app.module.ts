import { Module } from '@nestjs/common';
import { AuthModule } from './auth/auth.module.js';
import { ConfigModule } from '@nestjs/config';
import { envSchema } from './config/env.schema.js';

@Module({
  imports: [
    ConfigModule.forRoot({
      isGlobal: true,
      skipProcessEnv: true,
      validate: (config) => {
        const { DATABASE_URL } = envSchema.parse(config);
        return { DATABASE_URL };
      },
    }),
    AuthModule,
  ],
})
export class AppModule {}
