# Multi-stage build for frontend
# Stage 1: Build stage (not needed for static files, but keeping structure for future enhancements)
FROM nginx:alpine AS production

# Set working directory
WORKDIR /usr/share/nginx/html

# Remove default nginx static assets
RUN rm -rf ./*

# Copy static files
COPY index.html .
COPY script.js .
COPY styles.css .
COPY config.js .

# Copy custom nginx configuration
COPY nginx.conf /etc/nginx/nginx.conf

# Create directories with proper permissions for non-root nginx
RUN mkdir -p /tmp/nginx && \
    mkdir -p /var/cache/nginx/client_temp && \
    mkdir -p /var/cache/nginx/proxy_temp && \
    mkdir -p /var/cache/nginx/fastcgi_temp && \
    mkdir -p /var/cache/nginx/uwsgi_temp && \
    mkdir -p /var/cache/nginx/scgi_temp && \
    chown -R nginx:nginx /tmp/nginx && \
    chown -R nginx:nginx /var/cache/nginx && \
    chown -R nginx:nginx /var/log/nginx && \
    chown -R nginx:nginx /etc/nginx/conf.d && \
    chown -R nginx:nginx /usr/share/nginx/html && \
    chmod -R 755 /var/cache/nginx && \
    chmod -R 755 /var/log/nginx

# Switch to non-root user
USER nginx

# Expose port
EXPOSE 8080

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD wget --no-verbose --tries=1 --spider http://localhost:8080/ || exit 1

# Start nginx
CMD ["nginx", "-g", "daemon off;"]