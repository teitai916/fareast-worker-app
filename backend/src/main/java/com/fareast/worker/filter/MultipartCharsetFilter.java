package com.fareast.worker.filter;

import jakarta.servlet.Filter;
import jakarta.servlet.FilterChain;
import jakarta.servlet.FilterConfig;
import jakarta.servlet.ServletException;
import jakarta.servlet.ServletRequest;
import jakarta.servlet.ServletResponse;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletRequestWrapper;
import jakarta.servlet.http.HttpServletResponse;

import org.springframework.stereotype.Component;

import java.io.IOException;

/**
 * 解决 Flutter http.MultipartRequest 发送 multipart/form-data 时
 * 带 charset=UTF-8 导致 Spring Boot 无法解析的问题
 * 
 * 原理：在请求到达 Spring MVC 之前，移除 Content-Type 中的 charset 参数
 */
@Component
public class MultipartCharsetFilter implements Filter {

    @Override
    public void doFilter(ServletRequest request, ServletResponse response, FilterChain chain)
            throws IOException, ServletException {
        
        if (request instanceof HttpServletRequest) {
            HttpServletRequest httpRequest = (HttpServletRequest) request;
            String contentType = httpRequest.getContentType();
            
            // 只处理 multipart/form-data 且带 charset 的请求
            if (contentType != null 
                    && contentType.toLowerCase().contains("multipart/form-data")
                    && contentType.toLowerCase().contains("charset")) {
                
                // 移除 charset 参数，保留 boundary
                String newContentType = removeCharsetFromContentType(contentType);
                
                // 使用包装器修改 getContentType() 的返回值
                HttpServletRequest wrappedRequest = new ContentTypeRequestWrapper(httpRequest, newContentType);
                chain.doFilter(wrappedRequest, response);
                return;
            }
        }
        
        // 其他请求直接放行
        chain.doFilter(request, response);
    }
    
    /**
     * 从 Content-Type 中移除 charset 参数
     * 例如：multipart/form-data; boundary=xxx; charset=UTF-8
     * 变为：multipart/form-data; boundary=xxx
     */
    private String removeCharsetFromContentType(String contentType) {
        // 移除 "; charset=xxx" 或 ";charset=xxx"
        return contentType.replaceAll("\\s*;\\s*charset\\s*=\\s*[^;\\s]*", "");
    }
    
    /**
     * HttpServletRequest 包装器，用于修改 getContentType() 的返回值
     */
    private static class ContentTypeRequestWrapper extends HttpServletRequestWrapper {
        private final String newContentType;
        
        public ContentTypeRequestWrapper(HttpServletRequest request, String newContentType) {
            super(request);
            this.newContentType = newContentType;
        }
        
        @Override
        public String getContentType() {
            return newContentType;
        }
        
        @Override
        public String getHeader(String name) {
            if ("content-type".equalsIgnoreCase(name)) {
                return newContentType;
            }
            return super.getHeader(name);
        }
    }
}
