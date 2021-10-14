const GrokError = error{
    file_not_accesible,
    pattern_not_found,
    error_unexpected_read_size,
    error_compile_failed,
    error_uninitialized,
    error_pcre_error,
    error_nomatch,
    unknown_error,
};

pub fn get_error(n: c_int) GrokError {
    return switch (n) {
        1 => GrokError.file_not_accesible,
        2 => GrokError.pattern_not_found,
        3 => GrokError.error_unexpected_read_size,
        4 => GrokError.error_compile_failed,
        5 => GrokError.error_uninitialized,
        6 => GrokError.error_pcre_error,
        7 => GrokError.error_nomatch,
        else => GrokError.unknown_error,
    };
}
