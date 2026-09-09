{%- set apples = ["red", "green", "blue", ] -%}

{% for apple in apples %}
  {% if apple != "red" %}
    {{ apple }}
  {% else %}
    i hate {{ apple }}
  {% endif %}
{% endfor %}