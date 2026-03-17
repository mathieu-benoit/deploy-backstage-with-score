import '@backstage/cli/asset-types';
import ReactDOM from 'react-dom/client';
import { createApp } from '@backstage/frontend-defaults';
import { convertLegacyAppRoot, convertLegacyAppOptions } from '@backstage/core-compat-api';
import { apis } from './apis';
import { routes } from './App';
import '@backstage/ui/css/styles.css';

const app = createApp({
  features: [
    // Convert legacy API factory configurations to the new frontend system
    convertLegacyAppOptions({ apis }),
    // Convert legacy route structure to new frontend system features
    ...convertLegacyAppRoot(routes),
  ],
});

ReactDOM.createRoot(document.getElementById('root')!).render(app.createRoot());
