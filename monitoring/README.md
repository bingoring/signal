# Signal Monitoring Stack

Comprehensive monitoring and observability setup for the Signal application.

## Quick Start

```bash
# Set up the complete monitoring stack
./scripts/setup-monitoring.sh

# Set up only specific components
./scripts/setup-monitoring.sh -s prometheus  # Prometheus + AlertManager only
./scripts/setup-monitoring.sh -s grafana     # Grafana + Prometheus
./scripts/setup-monitoring.sh -s elk         # ELK Stack only

# Production setup with custom retention
./scripts/setup-monitoring.sh -e production -r 90d -m 4g
```

## Architecture

### Prometheus Stack
- **Prometheus**: Metrics collection and storage
- **AlertManager**: Alert routing and notifications
- **Grafana**: Visualization and dashboards
- **Node Exporter**: System metrics
- **PostgreSQL Exporter**: Database metrics
- **Redis Exporter**: Cache metrics
- **Blackbox Exporter**: Endpoint monitoring

### ELK Stack (Alternative/Additional Logging)
- **Elasticsearch**: Log storage and search
- **Logstash**: Log processing and parsing
- **Kibana**: Log visualization and analysis

### Loki Stack (Lightweight Alternative)
- **Loki**: Log aggregation
- **Promtail**: Log shipping

## Monitoring Targets

### Application Services
- Signal Backend API (port 8080)
- Signal WebSocket Service (port 8081)
- Custom business metrics at `/api/metrics`

### Infrastructure
- PostgreSQL database
- Redis cache
- System resources (CPU, memory, disk)
- Docker containers
- Network endpoints

### Business Metrics
- Signal creation rate
- User authentication events
- WebSocket connection counts
- API response times and error rates

## Access Points

After running the setup script:

- **Prometheus**: http://localhost:9090
- **AlertManager**: http://localhost:9093
- **Grafana**: http://localhost:3000 (admin/admin_password_change_me)
- **Elasticsearch**: http://localhost:9200
- **Kibana**: http://localhost:5601
- **Loki**: http://localhost:3100

## Configuration Files

### Prometheus Configuration
- `prometheus/prometheus.yml`: Main Prometheus configuration
- `prometheus/alert_rules.yml`: Alerting rules

### Grafana Configuration
- `grafana/provisioning/`: Datasources and dashboard provisioning
- `grafana/signal-overview-dashboard.json`: Main application dashboard

### ELK Configuration
- `elk/elasticsearch.yml`: Elasticsearch settings
- `elk/kibana.yml`: Kibana configuration
- `elk/elasticsearch-template.json`: Index template for Signal logs
- `logstash/config/logstash.yml`: Logstash configuration
- `logstash/pipeline/signal-logs.conf`: Log processing pipeline

### Alert Configuration
- `alertmanager/alertmanager.yml`: Alert routing and notification settings

## Security Notes

⚠️ **Important Security Considerations:**

1. **Change default passwords** in production:
   - Grafana admin password
   - AlertManager webhook URLs
   - Database connection strings

2. **Enable authentication** for production deployments
3. **Configure SSL/TLS** for external access
4. **Review alert notification channels** (Slack, email)
5. **Restrict network access** to monitoring services

## Customization

### Adding Custom Metrics

1. Instrument your application with Prometheus metrics
2. Update `prometheus/prometheus.yml` to add new scrape targets
3. Create custom Grafana dashboards
4. Add relevant alerting rules

### Log Format Requirements

The Logstash pipeline expects logs in JSON format with these fields:
```json
{
  "timestamp": "2024-01-01T12:00:00Z",
  "level": "INFO",
  "service": "backend",
  "message": "User authenticated",
  "request_id": "req-123",
  "user_id": "user-456"
}
```

### Environment-Specific Configuration

The setup script supports different environments:
- `development`: Basic setup with reduced retention
- `staging`: Production-like setup with moderate retention
- `production`: Full setup with extended retention and enhanced security

## Troubleshooting

### Common Issues

1. **Services not starting**: Check Docker daemon and available ports
2. **Metrics not appearing**: Verify service targets in Prometheus
3. **High resource usage**: Adjust memory limits in docker-compose.yml
4. **Alert notifications not working**: Check AlertManager configuration

### Log Locations

- Prometheus data: `/var/lib/docker/volumes/signal_prometheus_data`
- Grafana data: `/var/lib/docker/volumes/signal_grafana_data`
- Elasticsearch data: `/var/lib/docker/volumes/signal_elasticsearch_data`

### Health Checks

```bash
# Check service status
docker-compose -f monitoring/docker-compose.monitoring.yml ps

# View service logs
docker logs signal-prometheus
docker logs signal-grafana
docker logs signal-elasticsearch

# Test Prometheus targets
curl http://localhost:9090/api/v1/targets

# Test Grafana API
curl http://localhost:3000/api/health
```

## Maintenance

### Backup

Important data to backup:
- Grafana dashboards and datasources
- Prometheus configuration and rules
- AlertManager configuration
- Elasticsearch indices (if using ELK)

### Updates

1. Update Docker images in `docker-compose.monitoring.yml`
2. Review configuration changes in new versions
3. Test in staging before production deployment
4. Monitor for breaking changes in metrics schemas

### Scaling

For high-volume environments:
- Use Prometheus federation for multiple instances
- Implement remote storage for long-term retention
- Consider sharding Elasticsearch indices
- Use external alertmanager clustering