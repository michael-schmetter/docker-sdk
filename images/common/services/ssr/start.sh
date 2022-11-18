#!/bin/sh

git clone https://$GITHUB_TOKEN@github.com/spryker/fes.git . -b feature/hrz-294/fes-components-performance
npm i
nx build storefront
nx start-ssr-prod-socket storefront

/bin/sh