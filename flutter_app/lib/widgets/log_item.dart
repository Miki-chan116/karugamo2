import 'package:flutter/material.dart';

class LogItem extends StatelessWidget {
  final String time;
  final int count;
  final bool latest;
  final String? diff;

  const LogItem({
    super.key,
    required this.time,
    required this.count,
    this.latest = false,
    this.diff,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.white24),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          RichText(
            text: TextSpan(
              children: [
                if (time.contains(' '))
                  TextSpan(
                    text: "${time.split(' ')[0]} ",
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white70,
                    ),
                  ),
                TextSpan(
                  text: time.contains(' ') ? time.split(' ')[1] : time,
                  style: const TextStyle(
                    fontSize: 40,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              CircleAvatar(
                backgroundColor: Colors.transparent,
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFF4a9e6e),
                      width: 2,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      count.toString(),
                      style: TextStyle(
                        color: latest ? Colors.orange : Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                      ),
                    ),
                  ),
                ),
              ),
              if (diff != null) ...[
                const SizedBox(height: 4),
                Text(
                  diff!,
                  style: const TextStyle(
                    color: Colors.yellow,
                    fontSize: 16,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}