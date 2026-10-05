# HTTP

- **HTTP exceptions are thrown only in controllers and middleware.** Domain and service code throws domain errors; the HTTP layer alone maps them to status-carrying exceptions. An HTTP exception type imported below the controller layer is the smell — it couples business logic to one transport and breaks reuse from queues, jobs, and other entry points.
