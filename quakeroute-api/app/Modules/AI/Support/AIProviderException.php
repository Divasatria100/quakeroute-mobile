<?php

declare(strict_types=1);

namespace App\Modules\AI\Support;

use RuntimeException;

class AIProviderException extends RuntimeException
{
    public function __construct(
        string $message = 'AI provider failure',
        int $code = 0,
        ?\Throwable $previous = null,
        public readonly ?string $category = null,
    ) {
        parent::__construct($message, $code, $previous);
    }

    public static function timeout(string $message = 'AI provider timeout', ?\Throwable $previous = null): self
    {
        return new self($message, 0, $previous, 'timeout');
    }

    public static function unavailable(string $message = 'AI provider unavailable', ?\Throwable $previous = null): self
    {
        return new self($message, 0, $previous, 'unavailable');
    }

    public static function malformed(string $message = 'AI provider returned malformed response', ?\Throwable $previous = null): self
    {
        return new self($message, 0, $previous, 'malformed');
    }
}
