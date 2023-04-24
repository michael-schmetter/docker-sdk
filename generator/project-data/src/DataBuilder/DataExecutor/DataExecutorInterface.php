<?php

/**
 * This file is part of the Spryker Suite.
 * For full license information, please view the LICENSE file that was distributed with this source code.
 */

namespace ProjectData\DataBuilder\DataExecutor;

interface DataExecutorInterface
{
    public function exec(array $projectData): array;
}
