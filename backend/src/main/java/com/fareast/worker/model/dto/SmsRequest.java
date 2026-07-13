package com.fareast.worker.model.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class SmsRequest {

    @NotBlank(message = "手机号不能为空")
    @Pattern(regexp = "^\\d{8,11}$", message = "手机号格式不正确")
    private String phone;
}
