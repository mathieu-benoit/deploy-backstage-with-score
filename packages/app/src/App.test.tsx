import { renderWithEffects } from '@backstage/test-utils';
import { createApp } from '@backstage/frontend-defaults';
import {
  convertLegacyAppRoot,
  convertLegacyAppOptions,
} from '@backstage/core-compat-api';
import { apis } from './apis';
import { routes } from './App';

describe('App', () => {
  it('should render', async () => {
    process.env = {
      NODE_ENV: 'test',
      APP_CONFIG: [
        {
          data: {
            app: { title: 'Test' },
            backend: { baseUrl: 'http://localhost:7007' },
            techdocs: {
              storageUrl: 'http://localhost:7007/api/techdocs/static/docs',
            },
          },
          context: 'test',
        },
      ] as any,
    };

    const app = createApp({
      features: [
        convertLegacyAppOptions({ apis }),
        ...convertLegacyAppRoot(routes),
      ],
    });

    const { baseElement } = await renderWithEffects(app.createRoot());

    expect(baseElement).toBeInTheDocument();
  });
});
