from django.template import Library

register = Library()


@register.simple_tag(takes_context=True)
def absolute_uri(context, path):
    return context['request'].build_absolute_uri(path)
