import logging
import logging.handlers
import multiprocessing as mp

# Define clean layout string once at the top of the file
LOG_FORMAT = '%(asctime)s | %(levelname)-5s | %(message)s (%(filename)s:%(lineno)d)'
TIME_FORMAT = '%H:%M:%S'


def configure_logging(level=logging.INFO, log_queue=None):
    """
    This is called INSIDE the parallel worker processes.
    It tells the logger where to send its raw data.
    """
    # Catch ALL loggers
    logger = logging.getLogger()
    logger.setLevel(level)
    logger.handlers.clear()

    if log_queue:
        # Workers: cores route info to the multiprocessing queue - avoid race condition from print statements to stdout
        logger.addHandler(logging.handlers.QueueHandler(log_queue))
    else:
        # Sequential/Single-Core Mode: Print clean formatted messages straight to screen
        handler = logging.StreamHandler()
        handler.setFormatter(logging.Formatter(LOG_FORMAT, datefmt=TIME_FORMAT))
        logger.addHandler(handler)


def start_parallel_logging_listener():
    """
    This is called once in the main process right before the multiprocessing pool.
    It reads raw logs from the queue and applies the preferred formatting to logs outputted.
    """
    log_queue = mp.Manager().Queue()

    # This handler is responsible for printing the worker messages out to screen
    console_handler = logging.StreamHandler()
    console_handler.setFormatter(logging.Formatter(LOG_FORMAT, datefmt=TIME_FORMAT))

    # The listener pulls raw log notes from the queue and runs them through console_handler
    listener = logging.handlers.QueueListener(log_queue, console_handler)
    listener.start()

    return log_queue, listener
