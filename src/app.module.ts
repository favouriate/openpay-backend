import { Module } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import { envSchema } from './config/env.schema.js';
import { DatabaseModule } from './database/database.module.js';

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
    DatabaseModule,
  ],
})
export class AppModule {}
